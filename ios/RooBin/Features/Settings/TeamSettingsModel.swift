import Foundation

struct TeamSettingsModel:Equatable,Sendable {
 let name:String;let subsEnabled:Bool;let driversVoidSubs:Bool;let subAmount:Decimal;let logoURL:URL?
}
