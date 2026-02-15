const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Paths
const SOURCE_DIR = path.resolve(__dirname, '../llama.cpp/build/bin');
const TARGET_DIR = path.resolve(__dirname, '../src/addon/build/Release');

// Create target directory if it doesn't exist
if (!fs.existsSync(TARGET_DIR)) {
  fs.mkdirSync(TARGET_DIR, { recursive: true });
}

// Libraries to copy
const libraries = [
  'libllama.dylib',
  'libggml.dylib',
  'libggml-metal.dylib'
];

// Copy the libraries
libraries.forEach(lib => {
  const source = path.join(SOURCE_DIR, lib);
  const target = path.join(TARGET_DIR, lib);
  
  if (fs.existsSync(source)) {
    console.log(`Copying ${lib} to ${TARGET_DIR}`);
    fs.copyFileSync(source, target);
    
    // Fix the library paths using install_name_tool
    try {
      // Change the ID of the library
      execSync(`install_name_tool -id @loader_path/${lib} ${target}`);
      
      // If this is libllama.dylib, update its references to libggml.dylib
      if (lib === 'libllama.dylib') {
        execSync(`install_name_tool -change @rpath/libggml.dylib @loader_path/libggml.dylib ${target}`);
        execSync(`install_name_tool -change @rpath/libggml-metal.dylib @loader_path/libggml-metal.dylib ${target}`);
      }
      
      console.log(`Fixed paths for ${lib}`);
    } catch (error) {
      console.error(`Error fixing paths for ${lib}:`, error);
    }
  } else {
    console.error(`Library not found: ${source}`);
  }
});

console.log('Library copying and path fixing complete'); 