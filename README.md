# gitops-deploy-server

## Setup
Make sure you have enabled the Podman API Socket on the host ([learn more](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md)):

`systemctl --user enable --now podman.socket`

Make sure you can pull your local environment repository without any user interaction, either by making it public and using HTTPS or by using a read only PAT in the remote.

Mount the podman socket of your desired user into the container and set XDG_RUNTIME_DIR when running the container like so:
```
todo
```
or use the [provided compose file](podman-compose.yml).

## About
Simple ktor webserver, that exposes a deploy shell script via HTTP. The original purpose is to do push-based gitops,
where you can configure the pipeline of your environment repository to curl this server on update to re-deploy changed services.

See https://github.com/0815Sailsman/turing-environment for an example env repo and corresponding deploy.sh

The webserver has a single endpoint /deploy, that executes a deploy.sh in your configured working directory.

## Auth
todo
