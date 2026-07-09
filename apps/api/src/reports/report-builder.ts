import type { AnalysisRun } from "@feedingsystem/contracts";

type ReportCell = string | number;

interface ZipEntry {
  name: string;
  data: Buffer;
}

function xmlEscape(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function pdfEscape(value: string): string {
  return value.replaceAll("\\", "\\\\").replaceAll("(", "\\(").replaceAll(")", "\\)");
}

function formatValue(value: ReportCell): string {
  return typeof value === "number" ? String(value) : value;
}

function buildReportRows(run: AnalysisRun): Array<[string, ReportCell]> {
  return [
    ["Run ID", run.run_id],
    ["Mode", run.mode],
    ["Formula ID", run.formula_id ?? "-"],
    ["Created At", run.created_at],
    ["Stage", run.input_snapshot.stage],
    ["Objective", run.input_snapshot.objective],
    ["Average Weight (kg)", run.input_snapshot.avg_weight_kg],
    ["Head Count", run.input_snapshot.head_count],
    ["Target ADG", run.input_snapshot.target_adg ?? "-"],
    ["Total As-Fed (kg)", run.summary.total_as_fed_kg],
    ["Total DM (kg)", run.summary.total_dm_kg],
    ["Moisture (%)", run.summary.moisture_pct],
    ["CP (%DM)", run.summary.cp_pct_dm],
    ["TDN (%DM)", run.summary.tdn_pct_dm],
    ["NDF (%DM)", run.summary.ndf_pct_dm],
    ["ADF (%DM)", run.summary.adf_pct_dm],
    ["NFC (%DM)", run.summary.nfc_pct_dm],
    ["EE (%DM)", run.summary.ee_pct_dm],
    ["Ca (%DM)", run.summary.ca_pct_dm],
    ["P (%DM)", run.summary.p_pct_dm],
    ["Ca:P Ratio", run.summary.ca_p_ratio],
    ["Cost / Head / Day", run.summary.cost_per_head_day],
    ["Cost / kg", run.summary.cost_per_kg],
    ["Status CP", run.statuses.status_cp],
    ["Status TDN", run.statuses.status_tdn],
    ["Status NDF", run.statuses.status_ndf],
    ["Status ADF", run.statuses.status_adf],
    ["Status Ca", run.statuses.status_ca],
    ["Status P", run.statuses.status_p],
    ["Status Ca:P Ratio", run.statuses.status_ca_p_ratio],
    ["Status Moisture", run.statuses.status_moisture],
    ["Warnings", run.warnings.map((warning) => warning.code).join(", ") || "-"],
    [
      "Recommendations",
      run.recommendations
        .map((recommendation) => `${recommendation.rank}. ${recommendation.ingredient_id}`)
        .join(", ") || "-",
    ],
  ];
}

function createPdfObject(id: number, body: string): string {
  return `${id} 0 obj\n${body}\nendobj\n`;
}

export function buildPdfReport(run: AnalysisRun): Buffer {
  const lines = [
    "Hanwoo TMR Analysis Report",
    ...buildReportRows(run).map(([label, value]) => `${label}: ${formatValue(value)}`),
  ];

  const content = [
    "BT",
    "/F1 12 Tf",
    "50 770 Td",
    ...lines.flatMap((line, index) =>
      index === 0
        ? [`(${pdfEscape(line)}) Tj`]
        : ["0 -18 Td", `(${pdfEscape(line)}) Tj`],
    ),
    "ET",
  ].join("\n");

  const objects = [
    createPdfObject(1, "<< /Type /Catalog /Pages 2 0 R >>"),
    createPdfObject(2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    createPdfObject(
      3,
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    ),
    createPdfObject(4, `<< /Length ${Buffer.byteLength(content, "utf8")} >>\nstream\n${content}\nendstream`),
    createPdfObject(5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
  ];

  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  for (const object of objects) {
    offsets.push(Buffer.byteLength(pdf, "utf8"));
    pdf += object;
  }

  const xrefStart = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  for (let index = 1; index < offsets.length; index += 1) {
    pdf += `${String(offsets[index]).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF`;

  return Buffer.from(pdf, "utf8");
}

function isNumeric(value: ReportCell): value is number {
  return typeof value === "number";
}

function crc32(buffer: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      const mask = -(crc & 1);
      crc = (crc >>> 1) ^ (0xedb88320 & mask);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function createZip(entries: ZipEntry[]): Buffer {
  const localParts: Buffer[] = [];
  const centralParts: Buffer[] = [];
  let offset = 0;

  for (const entry of entries) {
    const nameBuffer = Buffer.from(entry.name, "utf8");
    const crc = crc32(entry.data);
    const localHeader = Buffer.alloc(30);
    localHeader.writeUInt32LE(0x04034b50, 0);
    localHeader.writeUInt16LE(20, 4);
    localHeader.writeUInt16LE(0, 6);
    localHeader.writeUInt16LE(0, 8);
    localHeader.writeUInt16LE(0, 10);
    localHeader.writeUInt16LE(0, 12);
    localHeader.writeUInt32LE(crc, 14);
    localHeader.writeUInt32LE(entry.data.length, 18);
    localHeader.writeUInt32LE(entry.data.length, 22);
    localHeader.writeUInt16LE(nameBuffer.length, 26);
    localHeader.writeUInt16LE(0, 28);

    const localRecord = Buffer.concat([localHeader, nameBuffer, entry.data]);
    localParts.push(localRecord);

    const centralHeader = Buffer.alloc(46);
    centralHeader.writeUInt32LE(0x02014b50, 0);
    centralHeader.writeUInt16LE(20, 4);
    centralHeader.writeUInt16LE(20, 6);
    centralHeader.writeUInt16LE(0, 8);
    centralHeader.writeUInt16LE(0, 10);
    centralHeader.writeUInt16LE(0, 12);
    centralHeader.writeUInt16LE(0, 14);
    centralHeader.writeUInt32LE(crc, 16);
    centralHeader.writeUInt32LE(entry.data.length, 20);
    centralHeader.writeUInt32LE(entry.data.length, 24);
    centralHeader.writeUInt16LE(nameBuffer.length, 28);
    centralHeader.writeUInt16LE(0, 30);
    centralHeader.writeUInt16LE(0, 32);
    centralHeader.writeUInt16LE(0, 34);
    centralHeader.writeUInt16LE(0, 36);
    centralHeader.writeUInt32LE(0, 38);
    centralHeader.writeUInt32LE(offset, 42);

    const centralRecord = Buffer.concat([centralHeader, nameBuffer]);
    centralParts.push(centralRecord);
    offset += localRecord.length;
  }

  const centralDirectory = Buffer.concat(centralParts);
  const endRecord = Buffer.alloc(22);
  endRecord.writeUInt32LE(0x06054b50, 0);
  endRecord.writeUInt16LE(0, 4);
  endRecord.writeUInt16LE(0, 6);
  endRecord.writeUInt16LE(entries.length, 8);
  endRecord.writeUInt16LE(entries.length, 10);
  endRecord.writeUInt32LE(centralDirectory.length, 12);
  endRecord.writeUInt32LE(offset, 16);
  endRecord.writeUInt16LE(0, 20);

  return Buffer.concat([...localParts, centralDirectory, endRecord]);
}

function buildSheetXml(rows: Array<[string, ReportCell]>): string {
  const header = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`;
  const cells = rows
    .map(([label, value], rowIndex) => {
      const excelRow = rowIndex + 1;
      const valueXml = isNumeric(value)
        ? `<c r="B${excelRow}"><v>${value}</v></c>`
        : `<c r="B${excelRow}" t="inlineStr"><is><t>${xmlEscape(formatValue(value))}</t></is></c>`;
      return `<row r="${excelRow}"><c r="A${excelRow}" t="inlineStr"><is><t>${xmlEscape(label)}</t></is></c>${valueXml}</row>`;
    })
    .join("");

  return `${header}<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${cells}</sheetData></worksheet>`;
}

export function buildXlsxReport(run: AnalysisRun): Buffer {
  const rows = buildReportRows(run);
  const sheetXml = buildSheetXml(rows);
  const entries: ZipEntry[] = [
    {
      name: "[Content_Types].xml",
      data: Buffer.from(
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` +
          `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
          `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` +
          `<Default Extension="xml" ContentType="application/xml"/>` +
          `<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` +
          `<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>` +
          `</Types>`,
        "utf8",
      ),
    },
    {
      name: "_rels/.rels",
      data: Buffer.from(
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` +
          `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
          `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>` +
          `</Relationships>`,
        "utf8",
      ),
    },
    {
      name: "xl/workbook.xml",
      data: Buffer.from(
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` +
          `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` +
          `<sheets><sheet name="Analysis" sheetId="1" r:id="rId1"/></sheets>` +
          `</workbook>`,
        "utf8",
      ),
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      data: Buffer.from(
        `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` +
          `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
          `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>` +
          `</Relationships>`,
        "utf8",
      ),
    },
    {
      name: "xl/worksheets/sheet1.xml",
      data: Buffer.from(sheetXml, "utf8"),
    },
  ];

  return createZip(entries);
}
