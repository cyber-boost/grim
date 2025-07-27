#!/usr/bin/env node

const GrimInstaller = require('../lib/installer');

async function postInstall() {
    console.log('\n🗡️  Grim Reaper Post-Install Setup');
    console.log('==================================\n');
    
    const installer = new GrimInstaller();
    
    try {
        // Always update to latest version (safe update preserving configs/databases)
        if (installer.isInstalled()) {
            console.log('🔄 Updating Grim Reaper to latest version...');
            await installer.update();  // Safe update preserving existing data
        } else {
            console.log('📥 Installing Grim Reaper core components...');
            await installer.install();  // Fresh installation
        }
        
        console.log('\n✅ Setup complete! You can now use: grim <command>');
    } catch (error) {
        console.error('⚠️  Post-install setup failed:', error.message);
        console.log('💡 You can manually install by running: npx grim-reaper-installer');
        console.log('💡 Or the package will auto-install on first use');
    }
}

// Only run if not in CI/CD environment
if (!process.env.CI && !process.env.CONTINUOUS_INTEGRATION && !process.env.npm_config_global) {
    postInstall().catch(console.error);
}