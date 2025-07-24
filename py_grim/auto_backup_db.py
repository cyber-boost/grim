#!/usr/bin/env python3
"""
Grim Auto-Backup Database Integration
Provides database tracking and reporting for auto-backups
"""

import os
import sys
import sqlite3
import json
import datetime
import argparse
from pathlib import Path
from typing import List, Dict, Tuple, Optional
import humanize

# Configuration
GRAVEYARD_DIR = os.environ.get('GRAVEYARD_DIR', '/root/.graveyard')
AUTO_BACKUP_DIR = os.path.join(GRAVEYARD_DIR, 'auto_backups')
TRACKING_DB = os.path.join(AUTO_BACKUP_DIR, '.file_tracking.db')
GRIM_DB = '/opt/reaper/db/grimm.db'


class AutoBackupDB:
    def __init__(self):
        self.tracking_conn = sqlite3.connect(TRACKING_DB)
        self.tracking_conn.row_factory = sqlite3.Row
        self.grim_conn = sqlite3.connect(GRIM_DB)
        self.grim_conn.row_factory = sqlite3.Row
        self._ensure_tables()
    
    def _ensure_tables(self):
        """Ensure database tables exist"""
        # Create tables if they don't exist
        self.tracking_conn.executescript('''
            CREATE TABLE IF NOT EXISTS file_tracking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT UNIQUE NOT NULL,
                last_modified INTEGER NOT NULL,
                last_backup INTEGER,
                backup_count INTEGER DEFAULT 0,
                total_size INTEGER DEFAULT 0,
                importance TEXT DEFAULT 'normal',
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            );
            
            CREATE TABLE IF NOT EXISTS backup_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                file_path TEXT NOT NULL,
                backup_path TEXT NOT NULL,
                backup_size INTEGER NOT NULL,
                compression_used TEXT,
                backup_time INTEGER DEFAULT (strftime('%s', 'now')),
                FOREIGN KEY (file_path) REFERENCES file_tracking(file_path)
            );
            
            CREATE INDEX IF NOT EXISTS idx_file_modified ON file_tracking(last_modified);
            CREATE INDEX IF NOT EXISTS idx_backup_time ON backup_history(backup_time);
        ''')
        
        # Create Grim integration tables
        self.grim_conn.executescript('''
            CREATE TABLE IF NOT EXISTS auto_backup_stats (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                total_files_monitored INTEGER DEFAULT 0,
                total_backups_created INTEGER DEFAULT 0,
                total_storage_used INTEGER DEFAULT 0,
                last_update INTEGER DEFAULT (strftime('%s', 'now'))
            );
        ''')
        
        self.tracking_conn.commit()
        self.grim_conn.commit()
    
    def get_statistics(self) -> Dict:
        """Get auto-backup statistics"""
        cursor = self.tracking_conn.cursor()
        
        stats = {
            'total_files': cursor.execute('SELECT COUNT(*) FROM file_tracking').fetchone()[0],
            'total_backups': cursor.execute('SELECT COUNT(*) FROM backup_history').fetchone()[0],
            'total_storage': cursor.execute('SELECT SUM(backup_size) FROM backup_history').fetchone()[0] or 0,
            'hot_files': [],
            'recent_backups': []
        }
        
        # Get hot files
        hot_files = cursor.execute('''
            SELECT file_path, backup_count, last_modified, importance
            FROM file_tracking
            WHERE backup_count > 5
            ORDER BY backup_count DESC
            LIMIT 10
        ''').fetchall()
        
        for file in hot_files:
            stats['hot_files'].append({
                'path': file['file_path'],
                'backups': file['backup_count'],
                'last_modified': datetime.datetime.fromtimestamp(file['last_modified']).isoformat(),
                'importance': file['importance']
            })
        
        # Get recent backups
        recent = cursor.execute('''
            SELECT b.file_path, b.backup_path, b.backup_size, b.compression_used, b.backup_time
            FROM backup_history b
            ORDER BY b.backup_time DESC
            LIMIT 10
        ''').fetchall()
        
        for backup in recent:
            stats['recent_backups'].append({
                'file': backup['file_path'],
                'backup': backup['backup_path'],
                'size': humanize.naturalsize(backup['backup_size']),
                'compression': backup['compression_used'],
                'time': datetime.datetime.fromtimestamp(backup['backup_time']).isoformat()
            })
        
        # Update Grim database
        grim_cursor = self.grim_conn.cursor()
        grim_cursor.execute('''
            INSERT OR REPLACE INTO auto_backup_stats 
            (id, total_files_monitored, total_backups_created, total_storage_used)
            VALUES (1, ?, ?, ?)
        ''', (stats['total_files'], stats['total_backups'], stats['total_storage']))
        self.grim_conn.commit()
        
        return stats
    
    def list_backups(self, file_pattern: Optional[str] = None) -> List[Dict]:
        """List backups with optional filtering"""
        cursor = self.tracking_conn.cursor()
        
        if file_pattern:
            query = '''
                SELECT b.*, f.importance
                FROM backup_history b
                JOIN file_tracking f ON b.file_path = f.file_path
                WHERE b.file_path LIKE ?
                ORDER BY b.backup_time DESC
                LIMIT 100
            '''
            results = cursor.execute(query, (f'%{file_pattern}%',)).fetchall()
        else:
            query = '''
                SELECT b.*, f.importance
                FROM backup_history b
                JOIN file_tracking f ON b.file_path = f.file_path
                ORDER BY b.backup_time DESC
                LIMIT 100
            '''
            results = cursor.execute(query).fetchall()
        
        backups = []
        for row in results:
            backups.append({
                'file_path': row['file_path'],
                'backup_path': row['backup_path'],
                'size': humanize.naturalsize(row['backup_size']),
                'compression': row['compression_used'],
                'time': datetime.datetime.fromtimestamp(row['backup_time']).strftime('%Y-%m-%d %H:%M:%S'),
                'importance': row['importance']
            })
        
        return backups
    
    def get_storage_report(self) -> Dict:
        """Get detailed storage usage report"""
        cursor = self.tracking_conn.cursor()
        
        # Storage by compression type
        compression_stats = cursor.execute('''
            SELECT compression_used, COUNT(*) as count, SUM(backup_size) as total_size
            FROM backup_history
            GROUP BY compression_used
        ''').fetchall()
        
        # Storage by importance
        importance_stats = cursor.execute('''
            SELECT f.importance, COUNT(b.id) as count, SUM(b.backup_size) as total_size
            FROM backup_history b
            JOIN file_tracking f ON b.file_path = f.file_path
            GROUP BY f.importance
        ''').fetchall()
        
        # Storage by directory
        directory_stats = {}
        all_backups = cursor.execute('''
            SELECT file_path, backup_size FROM backup_history
        ''').fetchall()
        
        for backup in all_backups:
            dir_path = os.path.dirname(backup['file_path'])
            if dir_path not in directory_stats:
                directory_stats[dir_path] = {'count': 0, 'size': 0}
            directory_stats[dir_path]['count'] += 1
            directory_stats[dir_path]['size'] += backup['backup_size']
        
        report = {
            'by_compression': {},
            'by_importance': {},
            'by_directory': {},
            'total_storage': 0
        }
        
        for row in compression_stats:
            report['by_compression'][row['compression_used']] = {
                'count': row['count'],
                'size': row['total_size'],
                'size_human': humanize.naturalsize(row['total_size'])
            }
            report['total_storage'] += row['total_size']
        
        for row in importance_stats:
            report['by_importance'][row['importance']] = {
                'count': row['count'],
                'size': row['total_size'],
                'size_human': humanize.naturalsize(row['total_size'])
            }
        
        # Top 10 directories by size
        sorted_dirs = sorted(directory_stats.items(), key=lambda x: x[1]['size'], reverse=True)[:10]
        for dir_path, stats in sorted_dirs:
            report['by_directory'][dir_path] = {
                'count': stats['count'],
                'size': stats['size'],
                'size_human': humanize.naturalsize(stats['size'])
            }
        
        report['total_storage_human'] = humanize.naturalsize(report['total_storage'])
        
        return report
    
    def cleanup_old_backups(self, days: int = 30) -> int:
        """Remove backups older than specified days"""
        cutoff_time = int((datetime.datetime.now() - datetime.timedelta(days=days)).timestamp())
        
        cursor = self.tracking_conn.cursor()
        
        # Get old backups
        old_backups = cursor.execute('''
            SELECT backup_path FROM backup_history
            WHERE backup_time < ?
        ''', (cutoff_time,)).fetchall()
        
        removed_count = 0
        for backup in old_backups:
            backup_path = backup['backup_path']
            if os.path.exists(backup_path):
                try:
                    os.remove(backup_path)
                    removed_count += 1
                except Exception as e:
                    print(f"Error removing {backup_path}: {e}")
        
        # Clean database records
        cursor.execute('DELETE FROM backup_history WHERE backup_time < ?', (cutoff_time,))
        self.tracking_conn.commit()
        
        return removed_count
    
    def close(self):
        """Close database connections"""
        self.tracking_conn.close()
        self.grim_conn.close()


def main():
    parser = argparse.ArgumentParser(description='Grim Auto-Backup Database Tool')
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Stats command
    subparsers.add_parser('stats', help='Show auto-backup statistics')
    
    # List command
    list_parser = subparsers.add_parser('list', help='List backups')
    list_parser.add_argument('--pattern', help='Filter by file pattern')
    
    # Storage command
    subparsers.add_parser('storage', help='Show storage usage report')
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser('cleanup', help='Clean old backups')
    cleanup_parser.add_argument('--days', type=int, default=30, help='Remove backups older than N days')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    db = AutoBackupDB()
    
    try:
        if args.command == 'stats':
            stats = db.get_statistics()
            print("\n=== Auto-Backup Statistics ===")
            print(f"Files monitored: {stats['total_files']}")
            print(f"Total backups: {stats['total_backups']}")
            print(f"Storage used: {humanize.naturalsize(stats['total_storage'])}")
            
            if stats['hot_files']:
                print("\nHot Files (frequently backed up):")
                for file in stats['hot_files']:
                    print(f"  - {file['path']}")
                    print(f"    Backups: {file['backups']}, Importance: {file['importance']}")
            
            if stats['recent_backups']:
                print("\nRecent Backups:")
                for backup in stats['recent_backups'][:5]:
                    print(f"  - {backup['file']} ({backup['time']})")
                    print(f"    Size: {backup['size']}, Compression: {backup['compression']}")
        
        elif args.command == 'list':
            backups = db.list_backups(args.pattern)
            print("\n=== Backups ===")
            for backup in backups:
                print(f"\n{backup['file_path']}")
                print(f"  Backup: {backup['backup_path']}")
                print(f"  Time: {backup['time']}, Size: {backup['size']}")
                print(f"  Compression: {backup['compression']}, Importance: {backup['importance']}")
        
        elif args.command == 'storage':
            report = db.get_storage_report()
            print("\n=== Storage Usage Report ===")
            print(f"Total storage: {report['total_storage_human']}")
            
            print("\nBy compression type:")
            for comp_type, stats in report['by_compression'].items():
                print(f"  {comp_type}: {stats['count']} files, {stats['size_human']}")
            
            print("\nBy importance level:")
            for importance, stats in report['by_importance'].items():
                print(f"  {importance}: {stats['count']} files, {stats['size_human']}")
            
            print("\nTop directories by size:")
            for dir_path, stats in report['by_directory'].items():
                print(f"  {dir_path}: {stats['count']} files, {stats['size_human']}")
        
        elif args.command == 'cleanup':
            removed = db.cleanup_old_backups(args.days)
            print(f"Removed {removed} old backups (older than {args.days} days)")
    
    finally:
        db.close()


if __name__ == '__main__':
    main()