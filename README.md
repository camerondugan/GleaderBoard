# GleaderBoard

A multiplayer game with a leaderboard written in gleam!

## Install dependencies: (only need choose one)

- [devenv.sh](https://devenv.sh/getting-started/) to get all dependencies automatically (my preference)
- Setup Gleam and Erlang on you machine manually: https://gleam.run/getting-started/installing/

## Run the server 
```bash
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N ''
gleam run
```

## In other terminal sessions
```bash
ssh localhost -p 2222
```

## Development

```sh
gleam run   # Run the project (starts ssh server on port 2222
gleam test  # Run the tests (it's just the default one gleam provided)
```
