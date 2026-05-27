# PowerShell Script to Convert Music Catalog for Web Access
# This script updates your music-catalog.csv to use web server URLs instead of local file paths

param(
    [Parameter(Mandatory=$false)]
    [string]$InputCsv = ".\music-catalog.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputCsv = ".\music-catalog-web.csv",
    
    [Parameter(Mandatory=$false)]
    [string]$ServerUrl = "http://localhost:8000"
)

Write-Host "🎵 Converting Music Catalog for Web Access" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if input CSV exists
if (-not (Test-Path $InputCsv)) {
    Write-Error "❌ Input CSV not found: $InputCsv"
    Write-Host "Please make sure the music-catalog.csv file exists."
    exit 1
}

Write-Host "📄 Reading CSV: $InputCsv" -ForegroundColor Yellow

try {
    # Import the CSV
    $musicCatalog = Import-Csv $InputCsv
    
    Write-Host "🔄 Processing $($musicCatalog.Count) tracks..." -ForegroundColor Green
    
    # Update each record with web-compatible URLs
    $updatedCatalog = $musicCatalog | ForEach-Object {
        # Convert Windows path separators to web path separators
        $webPath = $_.Relative_Path -replace '\\', '/'
        
        # URL encode special characters (spaces, etc.)
        $encodedPath = [System.Web.HttpUtility]::UrlPathEncode($webPath)
        
        # Create the new web URL
        $_.URL = "$ServerUrl/$encodedPath"
        
        # Also update File_Path to be web-compatible for local server access
        $_.File_Path = "$ServerUrl/$encodedPath"
        
        # Add web server status field
        $_ | Add-Member -NotePropertyName "Server_Required" -NotePropertyValue $true -Force
        $_ | Add-Member -NotePropertyName "Server_URL" -NotePropertyValue $ServerUrl -Force
        
        return $_
    }
    
    # Export the updated catalog
    Write-Host "💾 Exporting web-compatible catalog: $OutputCsv" -ForegroundColor Yellow
    
    $updatedCatalog | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Successfully created web-compatible music catalog!" -ForegroundColor Green
    
    # Display summary
    Write-Host "`n📊 CONVERSION SUMMARY" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host "Input file: $InputCsv" -ForegroundColor White
    Write-Host "Output file: $OutputCsv" -ForegroundColor White
    Write-Host "Tracks converted: $($updatedCatalog.Count)" -ForegroundColor White
    Write-Host "Server URL: $ServerUrl" -ForegroundColor White
    
    Write-Host "`n🌐 Sample Web URLs:" -ForegroundColor Yellow
    $updatedCatalog | Select-Object -First 3 | ForEach-Object {
        Write-Host "  $($_.Title) → $($_.URL)" -ForegroundColor White
    }
    
    Write-Host "`n🚀 NEXT STEPS:" -ForegroundColor Green
    Write-Host "==============" -ForegroundColor Green
    Write-Host "1. Start the music web server (see MUSIC_FILE_ACCESS_GUIDE.md)" -ForegroundColor White
    Write-Host "2. Import $OutputCsv into Power BI Desktop" -ForegroundColor White
    Write-Host "3. Use the 'URL' or 'File_Path' column in your Custom Visual" -ForegroundColor White
    Write-Host "4. Test playback with your DJ Mashup mode! 🎧" -ForegroundColor White
    
    Write-Host "`n⚡ Quick Server Test:" -ForegroundColor Magenta
    Write-Host "To verify server access, try opening these URLs in your browser after starting the server:" -ForegroundColor White
    $updatedCatalog | Select-Object -First 2 | ForEach-Object {
        Write-Host "  $($_.URL)" -ForegroundColor Gray
    }

} catch {
    Write-Error "❌ Error processing CSV: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n🎵 Ready for Power BI integration with web-accessible music files!" -ForegroundColor Green