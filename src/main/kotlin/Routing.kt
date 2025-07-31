package software.say

import io.ktor.http.HttpStatusCode
import io.ktor.server.application.*
import io.ktor.server.request.receiveChannel
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.utils.io.*
import kotlinx.io.readByteArray
import java.io.File

fun Application.configureRouting() {

    val webhookSecret = environment.config.property("gitops.webhook_secret").getString() ?: error("Missing WEBHOOK_SECRET")

    routing {
        route("/deploy") {
            post {
                val signatureHeader = call.request.headers["X-Hub-Signature-256"]
                val rawPayload = call.receiveChannel().toByteArray()

                if (!HmacVerifier.isValidSha256Signature(rawPayload, signatureHeader, webhookSecret)) {
                    call.respond(HttpStatusCode.Unauthorized, "Invalid signature")
                    return@post
                }

                val event = call.request.headers["X-GitHub-Event"]
                if (event != "push") {
                    call.respond(HttpStatusCode.OK, "Ignored event: $event")
                    return@post
                }

                val process = ProcessBuilder("./deploy.sh")
                    .directory(File(environment.config.property("gitops.environment_repo_directory").getString()))
                    .redirectOutput(ProcessBuilder.Redirect.INHERIT)
                    .redirectError(ProcessBuilder.Redirect.INHERIT)
                    .start()

                val exitCode = process.waitFor()

                if (exitCode == 0) {
                    call.respond(HttpStatusCode.OK, "Deploy successful")
                } else {
                    call.respond(HttpStatusCode.InternalServerError, "Deploy failed with code $exitCode")
                }
            }
        }
    }
}

suspend fun ByteReadChannel.toByteArray(): ByteArray {
    val packet = this.readRemaining()
    return packet.readByteArray()
}
