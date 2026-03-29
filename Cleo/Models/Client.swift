import Foundation
import CoreData

@objc(Client)
public class Client: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var email: String
    @NSManaged public var phone: String?
    @NSManaged public var address: String?
    @NSManaged public var defaultPaymentTermsDays: Int16
    @NSManaged public var isPinned: Bool

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var paymentTerms: PaymentTerms {
        get { PaymentTerms(rawValue: Int(defaultPaymentTermsDays)) ?? .net14 }
        set { defaultPaymentTermsDays = Int16(newValue.rawValue) }
    }
}
