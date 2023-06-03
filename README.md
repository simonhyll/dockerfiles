# Dockerfiles

## Getting started

```bash
# Clone the repository to "docker"
git clone https://github.com/simonhyll/dockerfiles docker
# At the top of each dockerfile you find  the command to run to use it
# For example:
docker build -f docker/tauri/build.dockerfile -o out .
```

## Images

| Image                  | Description                               |
| :--------------------- | :---------------------------------------- |
| tauri/build.dockerfile | Builds a Tauri application to the out dir |
