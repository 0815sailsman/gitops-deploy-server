package software.say

import io.ktor.http.HttpMethod
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun Application.configureRouting() {
    routing {
        route("/deploy", HttpMethod.Post) {
            handle {
                call.respondText("Hello")
            }
        }
    }
}
