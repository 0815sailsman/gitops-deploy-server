package software.say

import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.io.File

fun Application.configureRouting() {
    routing {
        route("/deploy") {
            post {
                val deployCommand = environment.config.property("gitops.deploy_command").getString()
                val workingDir = File(environment.config.property("gitops.environment_repo_directory").getString())

                val result = deployCommand.runCommand(workingDir)

                call.respondText(result ?: "Result was null!")
            }
        }
    }
}
