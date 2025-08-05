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
        route("/deploy-all-changed") {
            post {
                log.info("Request arrived...")
                val signatureHeader = call.request.headers["X-Hub-Signature-256"]
                val rawPayload = call.receiveChannel().toByteArray()

                if (!HmacVerifier.isValidSha256Signature(rawPayload, signatureHeader, webhookSecret)) {
                    log.info("Invalid signature")
                    call.respond(HttpStatusCode.Unauthorized, "Invalid signature")
                    return@post
                }

                val event = call.request.headers["X-GitHub-Event"]
                if (event != "push") {
                    log.info("Invalid event")
                    call.respond(HttpStatusCode.OK, "Ignored event: $event")
                    return@post
                }

                log.info("Calling deploy script...")
                val process = ProcessBuilder("./deploy-all-changed.sh")
                    .directory(File("/"))
                    .redirectOutput(ProcessBuilder.Redirect.INHERIT)
                    .redirectError(ProcessBuilder.Redirect.INHERIT)
                    .start()

                val exitCode = process.waitFor()
                log.info("Script retuned")

                if (exitCode == 0) {
                    log.info("Deploy successful")
                    call.respond(HttpStatusCode.OK, "Deploy successful")
                } else {
                    log.info("Failed")
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
