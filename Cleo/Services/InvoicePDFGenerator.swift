import UIKit

/// Generates PDF invoices matching the Arkie & Co. template style:
/// accent bar, large "Tax Invoice" title, clean two-column meta, grouped line items.
enum InvoicePDFGenerator {

    // A4 at 72 DPI
    private static let pageWidth: CGFloat  = 595.28
    private static let pageHeight: CGFloat = 841.89
    private static let margin: CGFloat     = 50
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - Colours (static neutrals — brand colour passed at call time)

    private static let textDark  = UIColor(white: 0.12, alpha: 1)
    private static let textMid   = UIColor(white: 0.35, alpha: 1)
    private static let textLight = UIColor(white: 0.55, alpha: 1)
    private static let ruleLine  = UIColor(white: 0.80, alpha: 1)

    // MARK: - Entry Point

    static func generate(invoice: Invoice, profile: BusinessProfile,
                         brandColor: UIColor = UIColor(red: 0.09, green: 0.18, blue: 0.32, alpha: 1)) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = 0

            y = drawAccentBar(y: y, color: brandColor)
            y = drawBusinessHeader(y: y, profile: profile)
            y = drawTaxInvoiceTitle(y: y, color: brandColor)
            y = drawMetaSection(y: y, invoice: invoice)
            drawHRule(y: y, color: ruleLine, thickness: 1)
            y += 1
            y = drawLineItemsTable(y: y, invoice: invoice)
            y = drawTotals(y: y, invoice: invoice)
            y = drawThankYouNote(y: y, color: brandColor)
            drawHRule(y: y, color: ruleLine, thickness: 1)
            y += 1
            drawPaymentSection(y: y, profile: profile)
        }
    }

    // MARK: - Accent Bar

    private static func drawAccentBar(y: CGFloat, color: UIColor) -> CGFloat {
        let barHeight: CGFloat = 6
        let rect = CGRect(x: 0, y: y, width: pageWidth, height: barHeight)
        color.setFill()
        UIBezierPath(rect: rect).fill()
        return barHeight + 28
    }

    // MARK: - Business Header

    private static func drawBusinessHeader(y: CGFloat, profile: BusinessProfile) -> CGFloat {
        var curY = y
        let x = margin

        // Logo — top right, up to 72pt square
        let logoSize: CGFloat = 72
        if let logoPath = profile.logoImagePath, !logoPath.isEmpty,
           let logo = UIImage(contentsOfFile: logoPath) {
            let logoX = margin + contentWidth - logoSize
            let logoRect = CGRect(x: logoX, y: curY, width: logoSize, height: logoSize)
            logo.draw(in: logoRect)
        }

        // Business name — large serif-style bold
        let nameFont = UIFont(name: "Georgia-Bold", size: 22) ?? UIFont.systemFont(ofSize: 22, weight: .bold)
        let nameAttr = NSAttributedString(string: profile.businessName.isEmpty ? "Your Business" : profile.businessName, attributes: [
            .font: nameFont,
            .foregroundColor: textDark
        ])
        nameAttr.draw(at: CGPoint(x: x, y: curY))
        curY += nameAttr.size().height + 3

        // App display name as tagline (if set and different from business name)
        if !profile.appDisplayName.isEmpty && profile.appDisplayName != profile.businessName {
            let taglineFont = UIFont.systemFont(ofSize: 11, weight: .medium)
            let taglineAttr = NSAttributedString(string: profile.appDisplayName, attributes: [
                .font: taglineFont,
                .foregroundColor: textMid
            ])
            taglineAttr.draw(at: CGPoint(x: x, y: curY))
            curY += taglineAttr.size().height + 10
        } else {
            curY += 6
        }

        // Contact details
        let detailFont = UIFont.systemFont(ofSize: 10)
        let details: [String] = [
            profile.address,
            profile.abn.map { "ABN: \($0)" },
            profile.email,
            profile.phone.map { "m \($0)" }
        ].compactMap { val -> String? in
            guard let v = val, !v.isEmpty else { return nil }
            return v
        }

        for detail in details {
            let attr = NSAttributedString(string: detail, attributes: [
                .font: detailFont,
                .foregroundColor: textMid
            ])
            attr.draw(at: CGPoint(x: x, y: curY))
            curY += attr.size().height + 2
        }

        // Ensure we clear the logo if it extends below the text block
        let logoBottom = y + 72
        return max(curY, logoBottom) + 20
    }

    // MARK: - "Tax Invoice" Title

    private static func drawTaxInvoiceTitle(y: CGFloat, color: UIColor) -> CGFloat {
        let font = UIFont(name: "Georgia-Bold", size: 36) ?? UIFont.systemFont(ofSize: 36, weight: .bold)
        let attr = NSAttributedString(string: "Tax Invoice", attributes: [
            .font: font,
            .foregroundColor: color
        ])
        attr.draw(at: CGPoint(x: margin, y: y))
        return y + attr.size().height + 20
    }

    // MARK: - Meta Section (Invoice for / Invoice # / Dates)

    private static func drawMetaSection(y: CGFloat, invoice: Invoice) -> CGFloat {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        let x = margin
        let rightEdge = margin + contentWidth
        var curY = y

        let labelFont  = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let valueFont  = UIFont.systemFont(ofSize: 10)
        let valueBold  = UIFont.systemFont(ofSize: 10, weight: .semibold)

        // Row 1: "Invoice for" (left) + "Invoice #" (right)
        let forLabel = NSAttributedString(string: "Invoice for", attributes: [.font: labelFont, .foregroundColor: textDark])
        forLabel.draw(at: CGPoint(x: x, y: curY))

        let numLabel = NSAttributedString(string: "Invoice #", attributes: [.font: labelFont, .foregroundColor: textDark])
        numLabel.draw(at: CGPoint(x: rightEdge - numLabel.size().width, y: curY))
        curY += forLabel.size().height + 4

        // Row 2: client name (left) + invoice number (right)
        let clientAttr = NSAttributedString(string: invoice.clientName.isEmpty ? "—" : invoice.clientName, attributes: [
            .font: valueFont, .foregroundColor: textMid
        ])
        clientAttr.draw(at: CGPoint(x: x, y: curY))

        let invNum = NSAttributedString(string: "#\(invoice.invoiceNumber)", attributes: [
            .font: valueBold, .foregroundColor: textMid
        ])
        invNum.draw(at: CGPoint(x: rightEdge - invNum.size().width, y: curY))
        curY += clientAttr.size().height + 2

        // Row 3: client email (left)
        if !invoice.clientEmail.isEmpty {
            let emailAttr = NSAttributedString(string: invoice.clientEmail, attributes: [
                .font: valueFont, .foregroundColor: textLight
            ])
            emailAttr.draw(at: CGPoint(x: x, y: curY))
            curY += emailAttr.size().height + 2
        }

        curY += 10

        // Dates row — right-aligned two columns
        let dateColWidth: CGFloat = 100
        let dateRightEdge = rightEdge
        let dateLeftEdge  = dateRightEdge - dateColWidth * 2

        // Headers
        let issueDateLabel = NSAttributedString(string: "Invoice date", attributes: [.font: labelFont, .foregroundColor: textDark])
        let dueDateLabel   = NSAttributedString(string: "Due date", attributes: [.font: labelFont, .foregroundColor: textDark])
        issueDateLabel.draw(at: CGPoint(x: dateLeftEdge, y: curY))
        dueDateLabel.draw(at: CGPoint(x: dateRightEdge - dueDateLabel.size().width, y: curY))
        curY += issueDateLabel.size().height + 3

        // Values
        let issueDateVal = NSAttributedString(string: df.string(from: invoice.issueDate ?? Date()), attributes: [
            .font: valueBold, .foregroundColor: textMid
        ])
        let dueDateVal = NSAttributedString(string: df.string(from: invoice.dueDate ?? Date()), attributes: [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: textDark
        ])
        issueDateVal.draw(at: CGPoint(x: dateLeftEdge, y: curY))
        dueDateVal.draw(at: CGPoint(x: dateRightEdge - dueDateVal.size().width, y: curY))
        curY += issueDateVal.size().height + 20

        return curY
    }

    // MARK: - Line Items Table

    private static func drawLineItemsTable(y: CGFloat, invoice: Invoice) -> CGFloat {
        let x = margin
        let rightEdge = margin + contentWidth
        var curY = y + 10

        let headerFont  = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let descBold    = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let descItalic  = UIFont(name: "Helvetica-Oblique", size: 10) ?? UIFont.systemFont(ofSize: 10)
        let cellFont    = UIFont.systemFont(ofSize: 10)

        // Column widths (as fractions of contentWidth)
        // Description takes most space, then qty, unit price, total
        let descW = contentWidth * 0.52
        let qtyW  = contentWidth * 0.12
        let upW   = contentWidth * 0.18

        let qtyX  = x + descW
        let upX   = qtyX + qtyW

        // Table header
        let descHeader  = NSAttributedString(string: "Description", attributes: [.font: headerFont, .foregroundColor: textDark])
        let totalHeader = NSAttributedString(string: "Total", attributes: [.font: headerFont, .foregroundColor: textDark])
        descHeader.draw(at: CGPoint(x: x, y: curY))
        totalHeader.draw(at: CGPoint(x: rightEdge - totalHeader.size().width, y: curY))
        curY += descHeader.size().height + 6

        drawHRule(y: curY, color: ruleLine, thickness: 1)
        curY += 8

        // Line items
        for item in invoice.lineItemsArray {
            let lineTotal = item.quantity * item.unitPrice

            // Description — bold
            let descAttr = NSMutableAttributedString(string: item.itemDescription, attributes: [
                .font: descBold, .foregroundColor: textDark
            ])
            let descRect = descAttr.boundingRect(
                with: CGSize(width: descW - 8, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], context: nil
            )
            descAttr.draw(in: CGRect(x: x, y: curY, width: descW - 8, height: descRect.height + 2))

            // Qty, unit price, total — right-aligned in their columns
            let qtyAttr   = NSAttributedString(string: formatQty(item.quantity), attributes: [.font: descItalic, .foregroundColor: textMid])
            let upAttr    = NSAttributedString(string: formatCurrency(item.unitPrice), attributes: [.font: cellFont, .foregroundColor: textMid])
            let totalAttr = NSAttributedString(string: formatCurrency(lineTotal), attributes: [.font: cellFont, .foregroundColor: textDark])

            qtyAttr.draw(at: CGPoint(x: qtyX + qtyW - qtyAttr.size().width, y: curY))
            upAttr.draw(at: CGPoint(x: upX + upW - upAttr.size().width, y: curY))
            totalAttr.draw(at: CGPoint(x: rightEdge - totalAttr.size().width, y: curY))

            curY += max(descRect.height, cellFont.lineHeight) + 6

            // Sub-description note if there's a quantity fraction (shows as italic below)
            if item.quantity != 1.0 && item.quantity != 0.0 {
                let noteStr = "\(formatQty(item.quantity)) × \(formatCurrency(item.unitPrice))"
                let noteAttr = NSAttributedString(string: noteStr, attributes: [
                    .font: descItalic, .foregroundColor: textLight
                ])
                noteAttr.draw(at: CGPoint(x: x, y: curY))
                curY += noteAttr.size().height + 4
            }

            drawHRule(y: curY, color: UIColor(white: 0.90, alpha: 1), thickness: 0.5)
            curY += 8
        }

        return curY + 8
    }

    // MARK: - Totals

    private static func drawTotals(y: CGFloat, invoice: Invoice) -> CGFloat {
        let rightEdge  = margin + contentWidth
        let labelEdge  = rightEdge - 120
        var curY = y

        let rowFont   = UIFont.systemFont(ofSize: 10)
        let totalFont = UIFont(name: "Georgia-Bold", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .bold)
        let totalValFont = UIFont(name: "Georgia-Bold", size: 15) ?? UIFont.systemFont(ofSize: 15, weight: .bold)

        func drawRow(label: String, value: String, lFont: UIFont, vFont: UIFont, color: UIColor) -> CGFloat {
            let lAttr = NSAttributedString(string: label, attributes: [.font: lFont, .foregroundColor: color])
            let vAttr = NSAttributedString(string: value, attributes: [.font: vFont, .foregroundColor: color])
            lAttr.draw(at: CGPoint(x: labelEdge - lAttr.size().width, y: curY))
            vAttr.draw(at: CGPoint(x: rightEdge - vAttr.size().width, y: curY))
            return curY + max(lAttr.size().height, vAttr.size().height) + 5
        }

        curY = drawRow(label: "Subtotal", value: formatCurrency(invoice.subtotal),
                       lFont: rowFont, vFont: rowFont, color: textLight)
        curY = drawRow(label: "Adjustments", value: formatCurrency(0),
                       lFont: rowFont, vFont: rowFont, color: textLight)

        if invoice.taxRate > 0 {
            curY = drawRow(label: "GST", value: formatCurrency(invoice.taxAmount),
                           lFont: rowFont, vFont: rowFont, color: textLight)
        }

        curY += 4
        drawHRule(y: curY, color: ruleLine, thickness: 1)
        curY += 10

        // "Total (including GST)" bold
        let totalLabel = invoice.taxRate > 0 ? "Total (including GST)" : "Total"
        curY = drawRow(label: totalLabel, value: formatCurrency(invoice.total),
                       lFont: totalFont, vFont: totalValFont, color: textDark)

        return curY + 20
    }

    // MARK: - Thank You Note

    private static func drawThankYouNote(y: CGFloat, color: UIColor) -> CGFloat {
        let font = UIFont(name: "Helvetica-BoldOblique", size: 11) ?? UIFont.italicSystemFont(ofSize: 11)
        let attr = NSAttributedString(string: "Sent with many thanks", attributes: [
            .font: font,
            .foregroundColor: color
        ])
        attr.draw(at: CGPoint(x: margin, y: y))
        return y + attr.size().height + 16
    }

    // MARK: - Payment Section

    private static func drawPaymentSection(y: CGFloat, profile: BusinessProfile) {
        var rows: [(String, String)] = []
        if let acctName = profile.accountName, !acctName.trimmingCharacters(in: .whitespaces).isEmpty {
            rows.append(("Account name", acctName))
        }
        if let bsb = profile.bsb, !bsb.isEmpty { rows.append(("BSB", bsb)) }
        if let acct = profile.accountNumber, !acct.isEmpty { rows.append(("Account number", acct)) }
        if let payID = profile.payID, !payID.isEmpty { rows.append(("PayID", payID)) }
        guard !rows.isEmpty else { return }

        var curY = y + 16
        let centerX = pageWidth / 2

        // "Payment kindly requested via transfer" — centred italic
        let headFont = UIFont(name: "Helvetica-Oblique", size: 10) ?? UIFont.italicSystemFont(ofSize: 10)
        let headAttr = NSAttributedString(string: "Payment kindly requested via transfer", attributes: [
            .font: headFont, .foregroundColor: textMid
        ])
        headAttr.draw(at: CGPoint(x: centerX - headAttr.size().width / 2, y: curY))
        curY += headAttr.size().height + 10

        // Label / value rows — centred as a block
        let labelFont = UIFont.systemFont(ofSize: 10)
        let valueFont = UIFont.systemFont(ofSize: 10)
        let colGap: CGFloat = 12
        let labelColW: CGFloat = 90

        for (label, value) in rows {
            let lAttr = NSAttributedString(string: label, attributes: [.font: labelFont, .foregroundColor: textLight])
            let vAttr = NSAttributedString(string: value, attributes: [.font: valueFont, .foregroundColor: textMid])
            let blockW = labelColW + colGap + vAttr.size().width
            let blockX = centerX - blockW / 2
            lAttr.draw(at: CGPoint(x: blockX, y: curY))
            vAttr.draw(at: CGPoint(x: blockX + labelColW + colGap, y: curY))
            curY += max(lAttr.size().height, vAttr.size().height) + 4
        }
    }

    // MARK: - Helpers

    private static func drawHRule(y: CGFloat, color: UIColor, thickness: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        path.lineWidth = thickness
        color.setStroke()
        path.stroke()
    }

    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    private static func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
