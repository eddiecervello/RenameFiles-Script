# RenameFiles - Quick Usage Guide

## 🚀 **Fastest Way to Get Started**

### Option 1: Use the Batch File (Easiest)
1. Double-click `Run-RenameFiles.bat` 
2. Or run from command prompt: `Run-RenameFiles.bat -Path "C:\Users\YourName\Downloads"`

### Option 2: Run Setup Wizard (Recommended for first-time users)
```cmd
pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1
```

### Option 3: Direct Command
```cmd
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\YourName\Downloads"
```

## 🔧 **If You Get Execution Policy Errors**

The script provides multiple solutions:

### Fix Once (Recommended)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Then you can run normally:
```powershell
pwsh .\RenameFiles.ps1 -Path "C:\Users\YourName\Downloads"
```

### Or Use Bypass Each Time
```powershell
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\YourName\Downloads"
```

## 📝 **Common Usage Examples**

### Test First (Dry Run)
```powershell
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\patoo\Downloads" -WhatIf
```

### Rename Files Once
```powershell
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\patoo\Downloads"
```

### Monitor Directory for Changes
```powershell
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Monitor -Path "C:\Users\patoo\Downloads"
```

### Run in Background
```powershell
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Background -Monitor -Path "C:\Users\patoo\Downloads"
```

## 🛠 **What the Script Does**

- Finds files created **today** in the specified directory
- Renames them by:
  - Replacing spaces with dashes
  - Removing numeric suffixes like (1), (2), etc.
  - Removing " - copy" patterns
- Creates unique names if conflicts exist
- Logs all operations in JSON format

## 📁 **Example Transformations**

- `my file (1).txt` → `my-file.txt`
- `document - copy.pdf` → `document.pdf`
- `photo copy (2).jpg` → `photo.jpg`

## ⚙ **Configuration**

After running the setup wizard, your preferences are saved in `RenameFiles-Config.json`:
- Watch directory
- File extensions to process
- Date format for conflicts
- Subdirectory inclusion

## 🆘 **Troubleshooting**

### Problem: "File cannot be loaded. The file is not digitally signed."
**Solution:** Use `-ExecutionPolicy Bypass` as shown above

### Problem: "Path does not exist"
**Solution:** Check the path exists and use quotes around paths with spaces

### Problem: Setup wizard shows syntax errors
**Solution:** Script has been fixed - use the updated version

### Problem: No files are renamed
**Solution:** The script only renames files created TODAY. Create a test file first:
```powershell
# Create a test file
New-Item -Path "C:\Users\patoo\Downloads\test file (1).txt" -ItemType File
# Then run the script
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\patoo\Downloads"
```

## 🎯 **Best Practices**

1. **Always test with `-WhatIf` first**
2. **Use the setup wizard for initial configuration**
3. **Run on your Downloads folder for best results**
4. **Use monitoring mode if you download files frequently**

---

**Need help?** Check the main README.md or create an issue on GitHub.