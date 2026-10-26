Write-Host "Building Flutter Web..." -ForegroundColor Cyan
flutter build web --release

Write-Host "Linking Vercel digital-life-app configuration..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "build\web\.vercel" | Out-Null
Copy-Item ".vercel\project.json" "build\web\.vercel\project.json" -Force

Write-Host "Deploying to production (ublife.universityofbohol.edu.ph)..." -ForegroundColor Green
npx vercel build/web --prod
