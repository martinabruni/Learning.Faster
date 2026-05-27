# Learning.Faster

Static GitHub Pages site for visual learning pages.

## Publishing model

- Repository type: GitHub Pages **project site**
- Recommended source: **`main` branch + `docs\` folder**
- Expected URL: `https://martinabruni.github.io/Learning.Faster/`

## Structure

```text
docs\
  index.html
  404.html
  .nojekyll
  assets\
    favicon.svg
  topics\
    dotnet10\
      index.html
```

## How to publish

1. Open the repository on GitHub.
2. Go to **Settings > Pages**.
3. Set **Build and deployment > Source** to **Deploy from a branch**.
4. Select **main** and **/docs**.
5. Save and wait for the Pages deployment.

If GitHub Pages is already enabled for the repository root (`main` + `/`), switch it to `main` + `/docs`. Repository **admin** permission is required for that settings change.

## Editing guidance

- Keep the site static-first unless a real build step becomes necessary.
- Prefer lowercase, folder-based URLs such as `docs\topics\new-topic\index.html`.
- Use relative links so pages work correctly under the project-site base path.
- Add a custom GitHub Actions workflow only if the site later needs compilation, bundling, validation, or generated content.
- Temporary root-level redirect files are present so the site still resolves cleanly until the Pages source is updated to `docs\`.
