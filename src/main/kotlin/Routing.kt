package software.say

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.utils.io.*
import kotlinx.io.readByteArray
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.io.File

fun Application.configureRouting() {

    val webhookSecret = environment.config.property("gitops.webhook_secret").getString() ?: error("Missing WEBHOOK_SECRET")

    routing {
        route("/health") {
            get {
                log.info("Health check request received")
                call.respond(HttpStatusCode.OK, "OK")
            }

        }

        route("/deploy-all-changed") {
            post {
                log.info("Request to deploy all changes arrived...")
                val signatureHeader = call.request.headers["X-Hub-Signature-256"]
                val rawPayload = call.receive<ByteArray>()

                if (!HmacVerifier.isValidSha256Signature(rawPayload, signatureHeader, webhookSecret)) {
                    log.info("Invalid signature")
                    call.respond(HttpStatusCode.Unauthorized, "Invalid signature")
                    return@post
                }

                val process = ProcessBuilder("./deploy-all-changed.sh")
                    .directory(File("/"))
                    .redirectOutput(ProcessBuilder.Redirect.INHERIT)
                    .redirectError(ProcessBuilder.Redirect.INHERIT)
                    .start()

                val exitCode = process.waitFor()
                log.info("Script returned")

                if (exitCode == 0) {
                    log.info("Deploy successful")
                    call.respond(HttpStatusCode.OK, "Deploy successful")
                } else {
                    log.info("Failed")
                    call.respond(HttpStatusCode.InternalServerError, "Deploy failed with code $exitCode")
                }
            }
        }

        route("/redeploy-and-update/{service-name}") {
            post {
                log.info("Request to re-deploy and update single arrived...")
                val signatureHeader = call.request.headers["X-Hub-Signature-256"]
                val rawPayload = call.receive<ByteArray>()

                if (!HmacVerifier.isValidSha256Signature(rawPayload, signatureHeader, webhookSecret)) {
                    log.info("Invalid signature")
                    call.respond(HttpStatusCode.Unauthorized, "Invalid signature")
                    return@post
                }

                val text = String(rawPayload, Charsets.UTF_8)
                val jsonBody = Json.decodeFromString(text) as JsonObject

                log.info("action ${(jsonBody["action"] as JsonPrimitive)}")
                if ((jsonBody["action"] as JsonPrimitive).content == "published") {
                    log.info("Calling deploy script...")
                    val process = ProcessBuilder("./redeploy-and-update.sh", call.parameters["service-name"])
                        .directory(File("/"))
                        .redirectOutput(ProcessBuilder.Redirect.INHERIT)
                        .redirectError(ProcessBuilder.Redirect.INHERIT)
                        .start()

                    val exitCode = process.waitFor()
                    log.info("Script returned")

                    if (exitCode == 0) {
                        log.info("Deploy of single service successful")
                        call.respond(HttpStatusCode.OK, "Deploy of single service successful")
                    } else {
                        log.info("Failed")
                        call.respond(HttpStatusCode.InternalServerError, "Deploy failed with code $exitCode")
                    }
                } else {
                    log.info("Updates are not considered here...")
                    call.respond(HttpStatusCode.OK, "Did not do anything because actions was not 'published'")
                }
            }
        }
    }
}

suspend fun ByteReadChannel.toByteArray(): ByteArray {
    val packet = this.readRemaining()
    return packet.readByteArray()
}
