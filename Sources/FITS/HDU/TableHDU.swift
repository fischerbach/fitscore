/*
 
 Copyright (c) <2020>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 */


import Foundation

public final class TableHDU : AnyTableHDU<TFIELD> {
    
    public required init(with data: inout Data) throws {
        try super.init(with: &data)
        
        self.initializeWrapper()
        
        self.buildTable()
    }
    
    required init() {
        super.init()
        // The value field shall contain the integer 2, de- noting that the included data array is two-dimensional: rows and columns.
        self.headerUnit.append(HeaderBlock(keyword: HDUKeyword.XTENSION, value: "TABLE", comment: nil))
        // The value field shall contain the integer 2, de- noting that the included data array is two-dimensional: rows and columns.
        self.headerUnit.append(HeaderBlock(keyword: HDUKeyword.NAXIS, value: 2, comment: "Two dimensional table"))
        // The value field shall contain the integer 0
        self.headerUnit.append(HeaderBlock(keyword: HDUKeyword.PCOUNT, value: 0, comment: nil))
        // The value field shall contain the integer 1; the data blocks contain a single table.
        self.headerUnit.append(HeaderBlock(keyword: HDUKeyword.GCOUNT, value: 1, comment: nil))
    }
    
    func buildTable() {
        
        let fieldCount = self.lookup(HDUKeyword.TFIELDS) ?? 0
        
        var format : [Int:(Int,Int)] = [:]
        
        // pre-fetch field properties
        for col in 0..<fieldCount {
            
            let rawTBCOL : Int = self.lookup("TBCOL\(col+1)") ?? 0
            let rawTTYPE : String? = self.lookup("TTYPE\(col+1)")
            let rawTUNIT : String? = self.lookup("TUNIT\(col+1)")
            let rawTFORM : TFORM? = self.lookup("TFORM\(col+1)")
            let rawTDISP : TDISP? = self.lookup("TDISP\(col+1)")
            
            if let tform = rawTFORM {
                self.table.append(TableColumn(self, (col+1), TDISP: rawTDISP, TFORM: tform, TUNIT: rawTUNIT, TTYPE: rawTTYPE))
                //_ = self.addColumnIMPL(index: col, TFORM: tform, TDISP: rawTDISP, TUNIT: rawTUNIT, TTYPE: rawTTYPE)
                format[col]  = (rawTBCOL,tform.length)
            }
        }
        
         // read actual values
        let rowLength = self.naxis(1) ?? 1
        let rows = self.naxis(2) ?? 0
        
        guard var data = self.dataUnit , data.count == rows * rowLength else {
            //print("Invalid data size \(dataUnit?.count ?? 0); Expected \(rows * rowLength)")
            return
        }
        
        for _ in 0..<rows {
            let row = data.subdata(in: 0..<rowLength)
            for columnIndex in 0..<table.count {
                let column = table[columnIndex]
                if let tfrom  = format[columnIndex] {
                    //print("\(rowIndex): \(column.TTYPE ?? "N/A"): \(column.TFORM) \(tfrom.0)...\(tfrom.0+tfrom.1)")
                    let val = row.subdata(in: tfrom.0-1..<tfrom.0+tfrom.1-1)
                    var string = String(data: val, encoding: .ascii) ?? ""
                    string = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let tform = column.TFORM {
                        let value = TFIELD.parse(string: string, type: tform)
                        #if DEBUG
                        value.raw = string
                        #endif
                        column.values.append(value)
                    }
                }
            }
            if data.count > rowLength {
                data = data.advanced(by: rowLength)
            } else {
                data = Data()
            }
        }
    }
    
}

extension TableHDU  {
    
    public var description: String {
        return "TABLE: \(self.lookup(HDUKeyword.TFIELDS) ?? -1)x\(self.naxis(2) ?? -1) Fields"
    }

    public var debugDescription: String {
        
        var result = ""
        result.append("-TABLE-------------------------------------\n")
        result.append("BITPIX: \(bitpix.debugDescription)\n")
        if naxis ?? 0 > 1 {
            result.append("NAXIS: \(naxis ?? 0)\n")
            for i in 1...naxis! {
                result.append("NAXIS\(i): \(naxis(i) ?? 0)\n")
            }
        }
        result.append("TFIELDS: \(self.lookup(HDUKeyword.TFIELDS) ?? 0)")
        result.append("-------------------------------------------\n")
        result.append("\(dataUnit.debugDescription)\n")
        result.append("-------------------------------------------\n")
        
        return result
    }
}
