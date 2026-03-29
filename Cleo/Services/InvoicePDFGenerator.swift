import UIKit

/// Generates professional PDF invoices using Core Graphics (§4.4)
enum InvoicePDFGenerator {

    // A4 at 72 DPI
    private static let pageWidth: CGFloat = 595.28
    private static let pageHeight: CGFloat = 841.89
    private static let margin: CGFloat = 40

    private static let contentWidth: CGFloat = 595.28 - 80 // pageWidth - 2*margin

    // Colors
    private static let black = UIColor(white: 0.1, alpha: 1)
    private static let darkGray = UIColor(white: 0.25, alpha: 1)
    private static let medGray = UIColor(white: 0.45, alpha: 1)
    private static let lightGray = UIColor(white: 0.6, alpha: 1)
    private static let lineColor = UIColor(white: 0.88, alpha: 1)
    private static let bgGray = UIColor(white: 0.96, alpha: 1)

    static func generate(invoice: Invoice, profile: BusinessProfile) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y = margin
            let x = margin

            // ── Header ──
            y = drawHeader(x: x, y: y, invoice: invoice, profile: profile)

            // ── Divider ──
            y += 12
            drawLine(x: x, y: y, width: contentWidth, color: black, thickness: 2)
            y += 16

            // ── Meta row: Bill To / Invoice Date / Due Date / Terms ──
            y = drawMetaRow(x: x, y: y, invoice: invoice)

            // ── Line items table ──
            y = drawLineItemsTable(x: x, y: y, invoice: invoice)

            // ── Totals ──
            y = drawTotals(x: x, y: y, invoice: invoice)

            // ── Payment Details ──
            y = drawPaymentDetails(x: x, y: y, profile: profile)

            // ── Notes ──
            y = drawNotes(x: x, y: y, invoice: invoice)

            // ── Footer ──
            drawFooter(pageRect: pageRect)
        }

        return data
    }

    // MARK: - Header

    private static func drawHeader(x: CGFloat, y: CGFloat, invoice: Invoice, profile: BusinessProfile) -> CGFloat {
        let curY = y

        // Logo (left side)
        var logoBottom = curY
        if let logoPath = profile.logoImagePath,
           let image = UIImage(contentsOfFile: logoPath) {
            let maxH: CGFloat = 50
            let maxW: CGFloat = 120
            let scale = min(maxW / image.size.width, maxH / image.size.height, 1)
            let w = image.size.width * scale
            let h = image.size.height * scale
            image.draw(in: CGRect(x: x, y: curY, width: w, height: h))
            logoBottom = curY + h + 6
        }

        // Business name
        let nameFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        let nameStr = NSAttributedString(string: profile.businessName, attributes: [
            .font: nameFont, .foregroundColor: black
        ])
        nameStr.draw(at: CGPoint(x: x, y: logoBottom))
        var detailY = logoBottom + nameStr.size().height + 2

        // Business details
        let detailFont = UIFont.systemFont(ofSize: 10)
        let details: [String] = [
            profile.abn.map { "ABN: \($0)" },
            profile.address,
            profile.email,
            profile.phone
        ].compactMap { $0?.isEmpty == true ? nil : $0 }

        for detail in details {
            let attr = NSAttributedString(string: detail, attributes: [
                .font: detailFont, .foregroundColor: lightGray
            ])
            attr.draw(at: CGPoint(x: x, y: detailY))
            detailY += attr.size().height + 1
        }

        // INVOICE title (right side)
        let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let titleStr = NSAttributedString(string: "INVOICE", attributes: [
            .font: titleFont, .foregroundColor: black
        ])
        let titleSize = titleStr.size()
        titleStr.draw(at: CGPoint(x: x + contentWidth - titleSize.width, y: curY))

        // Invoice number (right side)
        let numFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let numStr = NSAttributedString(string: invoice.invoiceNumber, attributes: [
            .font: numFont, .foregroundColor: lightGray
        ])
        let numSize = numStr.size()
        numStr.draw(at: CGPoint(x: x + contentWidth - numSize.width, y: curY + titleSize.height + 2))

        return max(detailY, curY + titleSize.height + numSize.height + 8)
    }

    // MARK: - Meta Row

    private static func drawMetaRow(x: CGFloat, y: CGFloat, invoice: Invoice) -> CGFloat {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"

        let labelFont = UIFont.systemFont(ofSize: 8, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 11)
        let valueBoldFont = UIFont.systemFont(ofSize: 11, weight: .semibold)

        // ── Left side: ISSUED TO ──
        var leftY = y

        let issuedLabel = NSAttributedString(string: "ISSUED TO:", attributes: [
            .font: labelFont, .foregroundColor: medGray,
            .kern: 1.0 as NSNumber
        ])
        issuedLabel.draw(at: CGPoint(x: x, y: leftY))
        leftY += issuedLabel.size().height + 4

        let clientLines: [String] = [
            invoice.clientName,
            invoice.clientEmail,
            invoice.clientAddress ?? ""
        ].filter { !$0.isEmpty }

        for (i, line) in clientLines.enumerated() {
            let font = (i == 0) ? valueBoldFont : valueFont
            let attr = NSAttributedString(string: line, attributes: [
                .font: font, .foregroundColor: darkGray
            ])
            attr.draw(at: CGPoint(x: x, y: leftY))
            leftY += attr.size().height + 1
        }

        // ── Right side: Invoice details (right-aligned) ──
        var rightY = y
        let rightEdge = x + contentWidth

        let detailRows: [(String, String)] = [
            ("INVOICE NO:", invoice.invoiceNumber),
            ("DATE:", dateFormatter.string(from: invoice.issueDate ?? Date())),
            ("DUE DATE:", dateFormatter.string(from: invoice.dueDate ?? Date())),
            ("TERMS:", invoice.paymentTerms.label)
        ]

        for (label, value) in detailRows {
            let labelAttr = NSAttributedString(string: label, attributes: [
                .font: labelFont, .foregroundColor: medGray,
                .kern: 1.0 as NSNumber
            ])
            let valueAttr = NSAttributedString(string: "  \(value)", attributes: [
                .font: valueFont, .foregroundColor: darkGray
            ])

            let totalWidth = labelAttr.size().width + valueAttr.size().width
            let rowX = rightEdge - totalWidth
            let rowHeight = max(labelAttr.size().height, valueAttr.size().height)
            let labelBaseline = rightY + (rowHeight - labelAttr.size().height)

            labelAttr.draw(at: CGPoint(x: rowX, y: labelBaseline))
            valueAttr.draw(at: CGPoint(x: rowX + labelAttr.size().width, y: rightY))

            rightY += rowHeight + 4
        }

        return max(leftY, rightY) + 20
    }

    // MARK: - Line Items Table

    private static func drawLineItemsTable(x: CGFloat, y: CGFloat, invoice: Invoice) -> CGFloat {
        let headerFont = UIFont.systemFont(ofSize: 8, weight: .semibold)
        let cellFont = UIFont.systemFont(ofSize: 11)

        let cols: [(String, CGFloat, Bool)] = [
            ("DESCRIPTION", 0.50, false),
            ("QTY", 0.15, true),
            ("UNIT PRICE", 0.17, true),
            ("AMOUNT", 0.18, true)
        ]

        var curY = y

        // Header row
        for col in cols {
            let colX = x + contentWidth * colOffset(col, in: cols)
            let colW = contentWidth * col.1
            let attr = NSAttributedString(string: col.0, attributes: [
                .font: headerFont, .foregroundColor: medGray,
                .kern: 1.0 as NSNumber
            ])
            let drawX = col.2 ? colX + colW - attr.size().width : colX
            attr.draw(at: CGPoint(x: drawX, y: curY))
        }
        curY += 18
        drawLine(x: x, y: curY, width: contentWidth, color: lineColor, thickness: 1.5)
        curY += 6

        // Data rows
        for item in invoice.lineItemsArray {
            let lineTotal = item.quantity * item.unitPrice
            let values: [String] = [
                item.itemDescription,
                formatQty(item.quantity),
                formatCurrency(item.unitPrice),
                formatCurrency(lineTotal)
            ]

            for (i, col) in cols.enumerated() {
                let colX = x + contentWidth * colOffset(col, in: cols)
                let colW = contentWidth * col.1
                let attr = NSAttributedString(string: values[i], attributes: [
                    .font: cellFont, .foregroundColor: darkGray
                ])
                let drawX = col.2 ? colX + colW - attr.size().width : colX
                attr.draw(at: CGPoint(x: drawX, y: curY))
            }

            curY += 22
            drawLine(x: x, y: curY, width: contentWidth, color: UIColor(white: 0.94, alpha: 1), thickness: 0.5)
            curY += 6
        }

        return curY + 8
    }

    // MARK: - Totals

    private static func drawTotals(x: CGFloat, y: CGFloat, invoice: Invoice) -> CGFloat {
        let totalsWidth: CGFloat = 220
        let totalsX = x + contentWidth - totalsWidth
        var curY = y

        let labelFont = UIFont.systemFont(ofSize: 11)
        let valueFont = UIFont.systemFont(ofSize: 11)
        let totalLabelFont = UIFont.systemFont(ofSize: 14, weight: .bold)
        let totalValueFont = UIFont.systemFont(ofSize: 14, weight: .bold)

        let taxPercent = Int(invoice.taxRate * 100)

        // Subtotal
        curY = drawTotalRow(x: totalsX, y: curY, width: totalsWidth,
                           label: "Subtotal", value: formatCurrency(invoice.subtotal),
                           labelFont: labelFont, valueFont: valueFont,
                           labelColor: lightGray, valueColor: darkGray)

        // GST
        curY = drawTotalRow(x: totalsX, y: curY, width: totalsWidth,
                           label: "GST (\(taxPercent)%)", value: formatCurrency(invoice.taxAmount),
                           labelFont: labelFont, valueFont: valueFont,
                           labelColor: lightGray, valueColor: darkGray)

        // Divider
        curY += 4
        drawLine(x: totalsX, y: curY, width: totalsWidth, color: black, thickness: 1.5)
        curY += 8

        // Total
        curY = drawTotalRow(x: totalsX, y: curY, width: totalsWidth,
                           label: "Total", value: formatCurrency(invoice.total),
                           labelFont: totalLabelFont, valueFont: totalValueFont,
                           labelColor: black, valueColor: black)

        return curY + 20
    }

    private static func drawTotalRow(x: CGFloat, y: CGFloat, width: CGFloat,
                                      label: String, value: String,
                                      labelFont: UIFont, valueFont: UIFont,
                                      labelColor: UIColor, valueColor: UIColor) -> CGFloat {
        let labelAttr = NSAttributedString(string: label, attributes: [
            .font: labelFont, .foregroundColor: labelColor
        ])
        labelAttr.draw(at: CGPoint(x: x, y: y))

        let valueAttr = NSAttributedString(string: value, attributes: [
            .font: valueFont, .foregroundColor: valueColor
        ])
        let valueSize = valueAttr.size()
        valueAttr.draw(at: CGPoint(x: x + width - valueSize.width, y: y))

        return y + max(labelAttr.size().height, valueSize.height) + 6
    }

    // MARK: - Payment Details

    private static func drawPaymentDetails(x: CGFloat, y: CGFloat, profile: BusinessProfile) -> CGFloat {
        // Collect pay-to rows: Account Name, BSB, Account No
        var payToRows: [(String, String)] = []
        payToRows.append(("Account Name", profile.businessName))
        if let bsb = profile.bsb, !bsb.isEmpty {
            payToRows.append(("BSB", bsb))
        }
        if let acct = profile.accountNumber, !acct.isEmpty {
            payToRows.append(("Account No", acct))
        }

        // Also collect extra details (Bank, PayID) for additional info
        let extras: [(String, String?)] = [
            ("Bank", profile.bankName),
            ("PayID", profile.payID)
        ]
        let validExtras = extras.compactMap { label, value -> (String, String)? in
            guard let v = value, !v.isEmpty else { return nil }
            return (label, v)
        }

        // Only show if we have at least BSB or Account
        let hasBankDetails = (profile.bsb != nil && !profile.bsb!.isEmpty)
            || (profile.accountNumber != nil && !profile.accountNumber!.isEmpty)
        guard hasBankDetails else { return y }

        let allRows = payToRows + validExtras

        var curY = y

        // Background box
        let boxHeight = CGFloat(allRows.count) * 16 + 36
        let boxRect = CGRect(x: x, y: curY, width: contentWidth, height: boxHeight)
        let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 6)
        bgGray.setFill()
        path.fill()

        curY += 10

        // Title
        let titleAttr = NSAttributedString(string: "PAY TO:", attributes: [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: medGray,
            .kern: 1.0 as NSNumber
        ])
        titleAttr.draw(at: CGPoint(x: x + 12, y: curY))
        curY += titleAttr.size().height + 6

        // Detail rows
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 10)

        for (label, value) in allRows {
            let str = NSMutableAttributedString()
            str.append(NSAttributedString(string: "\(label): ", attributes: [
                .font: labelFont, .foregroundColor: darkGray
            ]))
            str.append(NSAttributedString(string: value, attributes: [
                .font: valueFont, .foregroundColor: darkGray
            ]))
            str.draw(at: CGPoint(x: x + 12, y: curY))
            curY += str.size().height + 3
        }

        return curY + 16
    }

    // MARK: - Notes

    private static func drawNotes(x: CGFloat, y: CGFloat, invoice: Invoice) -> CGFloat {
        guard let notes = invoice.notes, !notes.isEmpty else { return y }

        var curY = y

        // Measure text first
        let valueFont = UIFont.systemFont(ofSize: 10)
        let notesAttr = NSAttributedString(string: notes, attributes: [
            .font: valueFont, .foregroundColor: darkGray
        ])
        let textRect = notesAttr.boundingRect(
            with: CGSize(width: contentWidth - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )

        let boxHeight = textRect.height + 36
        let boxRect = CGRect(x: x, y: curY, width: contentWidth, height: boxHeight)
        let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 6)
        bgGray.setFill()
        path.fill()

        curY += 10

        let titleAttr = NSAttributedString(string: "NOTES", attributes: [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: medGray,
            .kern: 1.0 as NSNumber
        ])
        titleAttr.draw(at: CGPoint(x: x + 12, y: curY))
        curY += titleAttr.size().height + 6

        notesAttr.draw(in: CGRect(x: x + 12, y: curY, width: contentWidth - 24, height: textRect.height + 4))

        return curY + textRect.height + 16
    }

    // MARK: - Footer

    private static func drawFooter(pageRect: CGRect) {
        let footerFont = UIFont.systemFont(ofSize: 9)
        let attr = NSAttributedString(string: "Thank you for your business.", attributes: [
            .font: footerFont, .foregroundColor: UIColor(white: 0.75, alpha: 1)
        ])
        let size = attr.size()
        attr.draw(at: CGPoint(
            x: (pageRect.width - size.width) / 2,
            y: pageRect.height - margin - size.height
        ))
    }

    // MARK: - Drawing Helpers

    private static func drawLine(x: CGFloat, y: CGFloat, width: CGFloat, color: UIColor, thickness: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        path.lineWidth = thickness
        color.setStroke()
        path.stroke()
    }

    private static func colOffset(_ col: (String, CGFloat, Bool), in cols: [(String, CGFloat, Bool)]) -> CGFloat {
        var offset: CGFloat = 0
        for c in cols {
            if c.0 == col.0 { break }
            offset += c.1
        }
        return offset
    }

    // MARK: - Formatters

    private static func formatCurrency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private static func formatQty(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
