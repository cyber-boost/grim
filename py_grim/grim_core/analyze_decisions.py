import os
import sys
import json
import sqlite3
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import tensorflow as tf
import torch
import joblib

# Add Grim root to path
grim_root = "/opt/grim"
sys.path.append(grim_root)

class GrimDecisionEngine:
    def __init__(self, db_path, models_dir, decisions_dir):
        self.db_path = db_path
        self.models_dir = models_dir
        self.decisions_dir = decisions_dir
        self.tf_model = None
        self.pt_model = None
        self.tf_scaler = None
        self.pt_scaler = None
        
    def load_models(self):
        """Load trained AI models"""
        try:
            # Load TensorFlow model
            tf_model_path = os.path.join(self.models_dir, 'tensorflow_backup_model')
            if os.path.exists(tf_model_path):
                self.tf_model = tf.keras.models.load_model(tf_model_path)
                self.tf_scaler = joblib.load(os.path.join(self.models_dir, 'tensorflow_scaler.pkl'))
                print("TensorFlow model loaded for decisions")
            
            # Load PyTorch model
            pt_model_path = os.path.join(self.models_dir, 'pytorch_backup_model.pth')
            if os.path.exists(pt_model_path):
                # Define model architecture
                class BackupPredictor(nn.Module):
                    def __init__(self, input_size):
                        super(BackupPredictor, self).__init__()
                        self.layer1 = nn.Linear(input_size, 128)
                        self.layer2 = nn.Linear(128, 64)
                        self.layer3 = nn.Linear(64, 32)
                        self.layer4 = nn.Linear(32, 3)
                        self.dropout = nn.Dropout(0.3)
                        self.relu = nn.ReLU()
                        
                    def forward(self, x):
                        x = self.dropout(self.relu(self.layer1(x)))
                        x = self.dropout(self.relu(self.layer2(x)))
                        x = self.relu(self.layer3(x))
                        x = self.layer4(x)
                        return x
                
                self.pt_model = BackupPredictor(7)
                self.pt_model.load_state_dict(torch.load(pt_model_path))
                self.pt_model.eval()
                self.pt_scaler = joblib.load(os.path.join(self.models_dir, 'pytorch_scaler.pkl'))
                print("PyTorch model loaded for decisions")
                
        except Exception as e:
            print(f"Error loading models: {e}")
            return False
        
        return True
    
    def get_file_data(self):
        """Get file data for analysis"""
        conn = sqlite3.connect(self.db_path)
        
        query = """
        SELECT 
            file_path,
            file_size,
            file_age_days,
            access_count,
            modification_count,
            backup_count,
            compression_ratio,
            CASE 
                WHEN file_type IN ('image', 'video', 'audio') THEN 1
                WHEN file_type IN ('document', 'text') THEN 2
                WHEN file_type IN ('archive', 'compressed') THEN 3
                ELSE 4
            END as file_type_encoded
        FROM file_statistics 
        WHERE file_size > 0
        ORDER BY file_size DESC
        LIMIT 1000
        """
        
        df = pd.read_sql_query(query, conn)
        conn.close()
        
        return df
    
    def make_backup_decision(self, file_data):
        """Make backup priority decision for a file"""
        features = file_data[['file_size', 'file_age_days', 'access_count', 
                             'modification_count', 'backup_count', 'compression_ratio', 
                             'file_type_encoded']].values.reshape(1, -1)
        
        decisions = {}
        
        # TensorFlow decision
        if self.tf_model is not None and self.tf_scaler is not None:
            features_scaled = self.tf_scaler.transform(features)
            tf_pred = self.tf_model.predict(features_scaled, verbose=0)
            tf_priority = np.argmax(tf_pred[0]) + 1
            tf_confidence = np.max(tf_pred[0])
            
            priority_labels = ['low', 'medium', 'high']
            decisions['tensorflow'] = {
                'priority': priority_labels[tf_priority - 1],
                'confidence': float(tf_confidence),
                'reasoning': f"File size: {file_data['file_size']}, Access count: {file_data['access_count']}"
            }
        
        # PyTorch decision
        if self.pt_model is not None and self.pt_scaler is not None:
            features_scaled = self.pt_scaler.transform(features)
            features_tensor = torch.FloatTensor(features_scaled)
            
            with torch.no_grad():
                pt_pred = self.pt_model(features_tensor)
                pt_probs = torch.softmax(pt_pred, dim=1)
                pt_priority = torch.argmax(pt_probs).item() + 1
                pt_confidence = torch.max(pt_probs).item()
            
            priority_labels = ['low', 'medium', 'high']
            decisions['pytorch'] = {
                'priority': priority_labels[pt_priority - 1],
                'confidence': float(pt_confidence),
                'reasoning': f"File age: {file_data['file_age_days']} days, Modifications: {file_data['modification_count']}"
            }
        
        return decisions
    
    def make_storage_optimization_decision(self, file_data):
        """Make storage optimization decision"""
        file_size = file_data['file_size']
        compression_ratio = file_data['compression_ratio']
        
        decisions = {}
        
        # Compression optimization
        if compression_ratio < 0.8:
            decisions['compression'] = {
                'action': 'compress',
                'potential_savings': file_size * (1 - compression_ratio),
                'confidence': 0.85,
                'reasoning': f"Current compression ratio: {compression_ratio:.2f}"
            }
        
        # Deduplication check (simplified)
        if file_size > 1000000:  # 1MB threshold
            decisions['deduplication'] = {
                'action': 'check_duplicates',
                'potential_savings': file_size * 0.1,  # Assume 10% potential savings
                'confidence': 0.7,
                'reasoning': f"Large file ({file_size} bytes) - check for duplicates"
            }
        
        return decisions
    
    def save_decisions(self, decisions_data):
        """Save decisions to database"""
        conn = sqlite3.connect(self.db_path)
        
        for file_path, decisions in decisions_data.items():
            for decision_type, decision in decisions.items():
                if decision_type in ['tensorflow', 'pytorch']:
                    # Backup priority decision
                    conn.execute("""
                        INSERT INTO ai_decisions 
                        (file_path, decision_type, decision_value, confidence, reasoning, ai_model_used)
                        VALUES (?, ?, ?, ?, ?, ?)
                    """, (
                        file_path,
                        'backup_priority',
                        decision['priority'],
                        decision['confidence'],
                        decision['reasoning'],
                        decision_type
                    ))
                    
                    # Update backup priorities table
                    conn.execute("""
                        INSERT OR REPLACE INTO backup_priorities 
                        (file_path, priority_level, priority_score, ai_confidence, decision_date)
                        VALUES (?, ?, ?, ?, ?)
                    """, (
                        file_path,
                        decision['priority'],
                        decision['confidence'],
                        decision['confidence'],
                        datetime.now()
                    ))
                
                elif decision_type in ['compression', 'deduplication']:
                    # Storage optimization decision
                    conn.execute("""
                        INSERT INTO ai_decisions 
                        (file_path, decision_type, decision_value, confidence, reasoning, ai_model_used)
                        VALUES (?, ?, ?, ?, ?, ?)
                    """, (
                        file_path,
                        'storage_optimization',
                        decision['action'],
                        decision['confidence'],
                        decision['reasoning'],
                        decision_type
                    ))
        
        conn.commit()
        conn.close()
        
        print(f"Saved {len(decisions_data)} file decisions to database")

def main():
    db_path = "/opt/grim/db/grimm.db"
    models_dir = "/opt/grim/models"
    decisions_dir = "/opt/grim/decisions"
    
    # Initialize decision engine
    engine = GrimDecisionEngine(db_path, models_dir, decisions_dir)
    
    # Load models
    if not engine.load_models():
        print("Failed to load models. Please train models first.")
        return
    
    # Get file data
    file_data = engine.get_file_data()
    
    if file_data.empty:
        print("No file data available for analysis")
        return
    
    print(f"Analyzing {len(file_data)} files...")
    
    decisions_data = {}
    
    # Process each file
    for _, row in file_data.iterrows():
        file_path = row['file_path']
        
        # Make backup decision
        backup_decisions = engine.make_backup_decision(row)
        
        # Make storage optimization decision
        storage_decisions = engine.make_storage_optimization_decision(row)
        
        # Combine decisions
        decisions_data[file_path] = {**backup_decisions, **storage_decisions}
    
    # Save decisions
    engine.save_decisions(decisions_data)
    
    # Generate summary
    total_files = len(decisions_data)
    high_priority = sum(1 for decisions in decisions_data.values() 
                       if any(d.get('priority') == 'high' for d in decisions.values() 
                             if isinstance(d, dict) and 'priority' in d))
    
    print(f"\nDecision Summary:")
    print(f"  Total files analyzed: {total_files}")
    print(f"  High priority files: {high_priority}")
    print(f"  High priority percentage: {(high_priority/total_files)*100:.1f}%")
    
    # Save summary to file
    summary = {
        'analysis_date': datetime.now().isoformat(),
        'total_files': total_files,
        'high_priority_files': high_priority,
        'high_priority_percentage': (high_priority/total_files)*100
    }
    
    summary_path = os.path.join(decisions_dir, 'analysis_summary.json')
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"Analysis summary saved to {summary_path}")

if __name__ == "__main__":
    main()
