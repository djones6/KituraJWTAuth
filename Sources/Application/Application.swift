import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import SwiftJWT
import CredentialsJWT

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()

    let key = "<PrivateKey>".data(using: .utf8)!

    func loginHandler(user: User, respondWith: (AccessToken?, RequestError?) -> Void) {
        var jwt = JWT(claims: ClaimsStandardJWT(iss: "Kitura", sub: user.name))
        guard let signedJWT = try? jwt.sign(using: .hs256(key: key))
            else {
                return respondWith(nil, .internalServerError)
        }
        respondWith(AccessToken(accessToken: signedJWT), nil)
    }

    public init() throws {
        // Run the metrics initializer
        initializeMetrics(router: router)
    }

    func postInit() throws {
        // Endpoints
        initializeHealthRoutes(app: self)

        // Issue a JWT
        router.post("/generateJWT", handler: loginHandler)

        // Type-safe JWTCredentials authentication
        TypeSafeJWT.verifier = .hs256(key: key)
        router.get("/protected") {  (jwt: JWT<MyClaims>, respondWith: (User?, RequestError?) -> Void) in
            let user = User(name: jwt.claims.sub)
            respondWith(user, nil)
        }
    }

    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}
