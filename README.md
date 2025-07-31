# gitops-deploy-server

Simple ktor webserver, that exposes a deploy shell script via HTTP. The original purpose is to do push-based gitops,
where you can configure the pipeline of your environment repository to curl this server on update to re-deploy changed services.

See https://github.com/0815Sailsman/turing-environment for an example env repo and corresponding deploy.sh

The webserver has a single endpoint /deploy, that executes a deploy.sh in your configured working directory.

## Auth
todo
