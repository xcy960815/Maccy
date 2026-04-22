import CryptoKit
import Foundation

let privateKey = Curve25519.Signing.PrivateKey()
let privateKeyBase64 = privateKey.rawRepresentation.base64EncodedString()
let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()

print("Sparkle private key (store as GitHub secret SPARKLE_PRIVATE_KEY):")
print(privateKeyBase64)
print("")
print("Sparkle public key (set as SUPublicEDKey in Info.plist):")
print(publicKeyBase64)
