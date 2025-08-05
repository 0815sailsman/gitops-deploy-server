# gitops-deploy-server

## About
Simple ktor webserver, that exposes a deploy shell script. The original purpose is to do push-based gitops,
where you can configure the pipeline of your environment repository to curl / webhook this server on update to re-deploy changed services.
The deploy script determines which services have changed by computing the hash of the compose file and the env files and comparing it to the deployed hash.

See https://github.com/0815Sailsman/turing-environment for an example env repo and corresponding deploy.sh

## Setup
Make sure you have enabled the Podman API Socket on the host ([learn more](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md)):

`systemctl --user enable --now podman.socket`

Make sure you can pull your local environment repository without any user interaction, either by making it public and using HTTPS or by using a read only PAT in the remote.

Mount the podman socket of your desired user into the container and set XDG_RUNTIME_DIR when running the container like so:
```
todo
```
or use the [provided compose file](podman-compose.yml).

## Endpoints

The webserver has two endpoints:
 - /deploy-all-changed: deploys all services in your configured environment repository that have changed since the last deploy (hash of compose and env files changed)
 - /redeploy-and-update/SERVICE_NAME: updates a single service, pulling the latest image and restarting it
   
## Architecture
This application is intended to be deployed as a container itself using podman. The provided compose file forwards the hosts podman API socket
to the container, which is then used by the deploy script to remotely control the hosts podman.

## Auth
todo
