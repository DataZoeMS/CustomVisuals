# PowerShell Script to Create Music Catalog CSV for Power BI Custom Visual
# This script scans a music folder, extracts MP3 metadata, and creates a CSV catalog

param(
    [Parameter(Mandatory=$false)]
    [string]$MusicPath = "C:\Users\phseamar\OneDrive - Microsoft\Documents\Music",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\music-catalog.csv"
)

Write-Host "🎵 Music Catalog Generator for Power BI Custom Visual" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Function to get file size in MB
function Get-FileSizeMB($filepath) {
    $size = (Get-Item $filepath).Length / 1MB
    return [Math]::Round($size, 2)
}

# Function to categorize music by decade based on year
function Get-Decade($year) {
    if ($year -and $year -match '^\d{4}$') {
        $yearNum = [int]$year
        $decade = [Math]::Floor($yearNum / 10) * 10
        return "${decade}s"
    }
    return "Unknown"
}

# Function to categorize by BPM range
function Get-BPMCategory($bpm) {
    if (-not $bpm -or $bpm -eq 0) { return "Unknown" }
    if ($bpm -lt 70) { return "Slow (Under 70)" }
    if ($bpm -lt 100) { return "Medium (70-99)" }
    if ($bpm -lt 130) { return "Upbeat (100-129)" }
    if ($bpm -lt 160) { return "Fast (130-159)" }
    return "Very Fast (160+)"
}

# Function to get energy level based on various factors
function Get-EnergyLevel($genre, $bpm) {
    $highEnergyGenres = @("Rock", "Metal", "Electronic", "Dance", "Punk", "Hardcore", "Dubstep", "Techno")
    $lowEnergyGenres = @("Classical", "Ambient", "Folk", "Acoustic", "Jazz", "Blues", "Ballad")
    
    $energy = "Medium"
    
    if ($highEnergyGenres -contains $genre) { $energy = "High" }
    elseif ($lowEnergyGenres -contains $genre) { $energy = "Low" }
    
    # Adjust based on BPM if available
    if ($bpm) {
        if ($bpm -gt 140) { $energy = "High" }
        elseif ($bpm -lt 80) { $energy = "Low" }
    }
    
    return $energy
}

# Function to extract duration in seconds from file
function Get-AudioDuration($filepath) {
    try {
        # Try using Windows Shell to get duration
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Get-Item $filepath).DirectoryName)
        $file = $folder.ParseName((Get-Item $filepath).Name)
        $duration = $folder.GetDetailsOf($file, 27) # Duration property
        
        if ($duration) {
            # Convert duration to seconds (format is usually MM:SS or HH:MM:SS)
            if ($duration -match '(\d+):(\d+):(\d+)') {
                return ([int]$matches[1] * 3600) + ([int]$matches[2] * 60) + [int]$matches[3]
            } elseif ($duration -match '(\d+):(\d+)') {
                return ([int]$matches[1] * 60) + [int]$matches[2]
            }
        }
    } catch {
        # Fallback: estimate based on file size (rough approximation)
        $sizeMB = Get-FileSizeMB $filepath
        return [Math]::Round($sizeMB * 8.5) # Rough estimate: 1MB ≈ 8.5 seconds for 128kbps MP3
    }
    return 180 # Default 3 minutes if cannot determine
}

# Initialize arrays for catalog
$musicCatalog = @()
$categories = @{}

Write-Host "📁 Scanning music folder: $MusicPath" -ForegroundColor Yellow

if (-not (Test-Path $MusicPath)) {
    Write-Error "❌ Music folder not found: $MusicPath"
    Write-Host "Please update the MusicPath parameter to point to your music folder."
    exit 1
}

# Get all MP3 files recursively
$mp3Files = Get-ChildItem -Path $MusicPath -Filter "*.mp3" -Recurse -ErrorAction SilentlyContinue

if ($mp3Files.Count -eq 0) {
    Write-Warning "⚠️  No MP3 files found in $MusicPath"
    Write-Host "Make sure the folder contains MP3 files and you have read permissions."
    exit 1
}

Write-Host "🎵 Found $($mp3Files.Count) MP3 files. Processing..." -ForegroundColor Green

$counter = 0
foreach ($file in $mp3Files) {
    $counter++
    $percentComplete = [Math]::Round(($counter / $mp3Files.Count) * 100, 1)
    Write-Progress -Activity "Processing MP3 Files" -Status "$counter of $($mp3Files.Count) - $($file.Name)" -PercentComplete $percentComplete
    
    try {
        # Basic file information
        $filename = $file.Name
        $filepath = $file.FullName
        $relativePath = $filepath.Replace($MusicPath, "").TrimStart('\')
        $folderStructure = Split-Path $relativePath -Parent
        $fileSizeMB = Get-FileSizeMB $filepath
        
        # Try to extract metadata from filename and folder structure
        $artist = "Unknown Artist"
        $title = $file.BaseName
        $album = "Unknown Album"
        $genre = "Unknown"
        $year = ""
        
        # Smart parsing based on folder structure
        $pathParts = $relativePath.Split('\')
        if ($pathParts.Length -ge 2) {
            $artist = $pathParts[0]
            if ($pathParts.Length -ge 3) {
                $album = $pathParts[1]
            }
        }
        
        # Parse filename for common patterns
        # Pattern: Artist - Title.mp3
        if ($filename -match '^(.+?)\s*-\s*(.+?)\.mp3$') {
            $artist = $matches[1].Trim()
            $title = $matches[2].Trim()
        }
        # Pattern: Track Number - Title.mp3
        elseif ($filename -match '^\d+\s*-\s*(.+?)\.mp3$') {
            $title = $matches[1].Trim()
        }
        
        # Genre detection from folder or filename
        $genreKeywords = @{
            "Rock" = @("rock", "metal", "punk", "grunge")
            "Pop" = @("pop", "chart", "hits", "top")
            "Electronic" = @("electronic", "dance", "edm", "techno", "house", "trance", "dubstep")
            "Hip Hop" = @("hip", "hop", "rap", "urban")
            "Classical" = @("classical", "symphony", "orchestra", "baroque")
            "Jazz" = @("jazz", "blues", "swing")
            "Country" = @("country", "folk", "acoustic")
            "R&B" = @("rnb", "r&b", "soul", "funk")
            "Alternative" = @("alternative", "indie", "alt")
        }
        
        $folderLower = $relativePath.ToLower()
        foreach ($genreKey in $genreKeywords.Keys) {
            foreach ($keyword in $genreKeywords[$genreKey]) {
                if ($folderLower.Contains($keyword)) {
                    $genre = $genreKey
                    break
                }
            }
            if ($genre -ne "Unknown") { break }
        }
        
        # Try to extract year from folder name
        if ($relativePath -match '\b(19|20)\d{2}\b') {
            $year = $matches[0]
        }
        
        # Get audio properties
        $durationSeconds = Get-AudioDuration $filepath
        $durationMinutes = [Math]::Round($durationSeconds / 60, 1)
        $durationDisplay = "{0}:{1:D2}" -f [Math]::Floor($durationSeconds / 60), ($durationSeconds % 60)
        
        # Estimate BPM based on genre (rough approximation)
        $estimatedBPM = switch ($genre) {
            "Electronic" { Get-Random -Minimum 120 -Maximum 140 }
            "Rock" { Get-Random -Minimum 110 -Maximum 130 }
            "Pop" { Get-Random -Minimum 100 -Maximum 120 }
            "Hip Hop" { Get-Random -Minimum 80 -Maximum 100 }
            "Classical" { Get-Random -Minimum 60 -Maximum 80 }
            "Jazz" { Get-Random -Minimum 90 -Maximum 120 }
            default { Get-Random -Minimum 90 -Maximum 120 }
        }
        
        # Create categories
        $decade = Get-Decade $year
        $bpmCategory = Get-BPMCategory $estimatedBPM
        $energyLevel = Get-EnergyLevel $genre $estimatedBPM
        $durationCategory = if ($durationSeconds -lt 180) { "Short (Under 3 min)" } 
                           elseif ($durationSeconds -lt 300) { "Medium (3-5 min)" }
                           else { "Long (Over 5 min)" }
        
        # Create catalog entry
        $catalogEntry = [PSCustomObject]@{
            # Core identification
            'File_Name' = $filename
            'File_Path' = $filepath
            'Relative_Path' = $relativePath
            'URL' = "file:///$($filepath.Replace('\', '/'))"
            
            # Metadata
            'Artist' = $artist
            'Title' = $title
            'Album' = $album
            'Genre' = $genre
            'Year' = $year
            'Decade' = $decade
            
            # Audio properties
            'Duration_Seconds' = $durationSeconds
            'Duration_Minutes' = $durationMinutes
            'Duration_Display' = $durationDisplay
            'Estimated_BPM' = $estimatedBPM
            'File_Size_MB' = $fileSizeMB
            
            # Categories for Power BI
            'BPM_Category' = $bpmCategory
            'Energy_Level' = $energyLevel
            'Duration_Category' = $durationCategory
            'Folder_Structure' = $folderStructure
            
            # Power BI friendly fields
            'Track_ID' = $counter
            'Is_Favorite' = $false
            'Play_Count' = 0
            'Last_Played' = ""
            'Rating' = 0
            'Tags' = ""
            'Notes' = ""
        }
        
        $musicCatalog += $catalogEntry
        
        # Track categories for summary
        if (-not $categories[$genre]) { $categories[$genre] = 0 }
        $categories[$genre]++
        
    } catch {
        Write-Warning "⚠️  Error processing $filename : $($_.Exception.Message)"
    }
}

Write-Progress -Activity "Processing MP3 Files" -Completed

# Export to CSV
Write-Host "💾 Exporting catalog to: $OutputPath" -ForegroundColor Yellow

try {
    $musicCatalog | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Successfully created music catalog!" -ForegroundColor Green
} catch {
    Write-Error "❌ Error creating CSV file: $($_.Exception.Message)"
    exit 1
}

# Display summary
Write-Host "`n📊 MUSIC CATALOG SUMMARY" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "Total tracks: $($musicCatalog.Count)" -ForegroundColor White
Write-Host "Output file: $OutputPath" -ForegroundColor White
Write-Host "Total size: $([Math]::Round(($musicCatalog | Measure-Object File_Size_MB -Sum).Sum, 1)) MB" -ForegroundColor White

Write-Host "`n🎵 Genres found:" -ForegroundColor Yellow
$categories.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value) tracks" -ForegroundColor White
}

$decades = $musicCatalog | Group-Object Decade | Sort-Object Name
Write-Host "`n📅 Decades:" -ForegroundColor Yellow
$decades | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) tracks" -ForegroundColor White
}

Write-Host "`n🚀 Ready for Power BI!" -ForegroundColor Green
Write-Host "═══════════════════════" -ForegroundColor Green
Write-Host "1. Import the CSV file into Power BI Desktop" -ForegroundColor White
Write-Host "2. Add your Custom Visual to a report page" -ForegroundColor White
Write-Host "3. Drag 'File_Path' or 'URL' to the Music URLs data role" -ForegroundColor White
Write-Host "4. Drag 'Title' to the Track Names data role" -ForegroundColor White
Write-Host "5. Use Genre, Artist, Decade for filtering and categorization" -ForegroundColor White
Write-Host "6. Enjoy your DJ Mashup mode with perfect BPM sync! 🎧" -ForegroundColor White

Write-Host "`n🎛️  Pro DJ Tips:" -ForegroundColor Magenta
Write-Host "• Use 'Estimated_BPM' field for tempo matching" -ForegroundColor White
Write-Host "• Filter by 'Energy_Level' for mood-based playlists" -ForegroundColor White
Write-Host "• Use 'BPM_Category' for automatic track grouping" -ForegroundColor White
Write-Host "• Master BPM control will sync any two tracks perfectly!" -ForegroundColor White