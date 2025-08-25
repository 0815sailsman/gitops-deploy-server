# gitops-deploy-server

See [video](https://youtu.be/JBilwVpcRb0) or [blogpost](https://blog.shonk.software/posts/gitops/
)

## About
Simple ktor webserver, that exposes deployment shell scripts. The original purpose is to do push-based gitops,
where you can configure the pipeline of your environment repository to curl / webhook this server on update to re-deploy changed services.
The deployment script determines which services have changed by computing the hash of the compose file and the env files and comparing it to the deployed hash.

See https://github.com/0815Sailsman/turing-environment for an example env repo and corresponding deploy.sh

## Setup
Make sure you have enabled the Podman API Socket on the host ([learn more](https://github.com/containers/podman/blob/main/docs/tutorials/socket_activation.md)):

`systemctl --user enable --now podman.socket`

Make sure you can pull your local environment repository without any user interaction, either by making it public and using HTTPS or by using a read only PAT in the remote.

Mount the podman socket of your desired user into the container and set XDG_RUNTIME_DIR when running the container using the [provided compose file](podman-compose.yml).

If you are running services in private ghcr registries, you will have to add a ghcr.cred file to the secrets directory of your environment repository.
It should contain a class PAT with read packages permission. Also make sure to set the env variable GITHUB_USERNAME in the compose file.
Disclaimer:
I am currently managing this service through itself and that is what the compose file is set up for.
Feel free to experiment with it yourself. If you find an an issue or build something for your setup, feel free to open a PR.
I will happily add it to the repo for everyone to use.

## Endpoints

The webserver has two endpoints (+ healthcheck):
 - /deploy-all-changed: deploys all services in your configured environment repository that have changed since the last deploy (hash of compose and env files changed)
 - /redeploy-and-update/SERVICE_NAME: updates a single service, pulling the latest image and restarting it
   
## Architecture
This application is intended to be deployed as a container itself using podman. The provided compose file forwards the hosts podman API socket
to the container, which is then used by the deploy script to remotely control the hosts podman.

## Auth
docs todo

## Known issues
calling the redeploy single endpoint gives the following warning:
```
level=warning msg="\"/run/user/1000\" directory set by $XDG_RUNTIME_DIR does not exist. Either create the directory or unset $XDG_RUNTIME_DIR.: faccessat /run/user/1000: no such file or directory: Trying to pull image in the event that it is a public image."
```
but everything still works, so Ill ignore it for now.