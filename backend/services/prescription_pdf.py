import io
import os
import tempfile
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from config import supabase_admin


# ─── Color Palette ──────────────────────────────────────────
PRIMARY_BLUE = HexColor("#1E88E5")
DARK_TEXT = HexColor("#2C3E50")
LIGHT_BG = HexColor("#F5F7FA")
GREEN = HexColor("#43A047")
GREY = HexColor("#95A5A6")


def _get_styles():
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name="RxTitle",
        fontSize=22,
        textColor=PRIMARY_BLUE,
        alignment=TA_CENTER,
        spaceAfter=6,
        fontName="Helvetica-Bold",
    ))
    styles.add(ParagraphStyle(
        name="RxSubtitle",
        fontSize=10,
        textColor=GREY,
        alignment=TA_CENTER,
        spaceAfter=12,
    ))
    styles.add(ParagraphStyle(
        name="SectionHeader",
        fontSize=13,
        textColor=PRIMARY_BLUE,
        spaceAfter=6,
        spaceBefore=14,
        fontName="Helvetica-Bold",
    ))
    styles.add(ParagraphStyle(
        name="FieldLabel",
        fontSize=9,
        textColor=GREY,
        fontName="Helvetica-Bold",
    ))
    styles.add(ParagraphStyle(
        name="FieldValue",
        fontSize=11,
        textColor=DARK_TEXT,
        spaceAfter=4,
    ))
    styles.add(ParagraphStyle(
        name="BulletItem",
        fontSize=10,
        textColor=DARK_TEXT,
        leftIndent=16,
        spaceAfter=3,
    ))
    styles.add(ParagraphStyle(
        name="Disclaimer",
        fontSize=8,
        textColor=GREY,
        alignment=TA_CENTER,
        spaceBefore=20,
    ))
    return styles


async def generate_and_upload_pdf(
    prescription_id: str,
    patient_info: dict,
    symptoms: str,
    disease: str,
    medicines: str,
    precautions: list,
    tests: list,
    doctor_notes: str = None,
) -> str:
    """Generate a professional prescription PDF and upload to Supabase Storage."""
    try:
        styles = _get_styles()
        buffer = io.BytesIO()

        doc = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            rightMargin=20 * mm,
            leftMargin=20 * mm,
            topMargin=15 * mm,
            bottomMargin=15 * mm,
        )

        elements = []

        # ─── Header ─────────────────────────────────────
        elements.append(Paragraph("🏥 MEDICARE AI", styles["RxTitle"]))
        elements.append(Paragraph("AI-Powered Health Assistant — Prescription Report", styles["RxSubtitle"]))
        elements.append(HRFlowable(width="100%", thickness=1.5, color=PRIMARY_BLUE))
        elements.append(Spacer(1, 8 * mm))

        # ─── Patient Info Table ──────────────────────────
        elements.append(Paragraph("PATIENT INFORMATION", styles["SectionHeader"]))

        patient_name = patient_info.get("name", "N/A")
        patient_age = patient_info.get("age", "N/A")
        patient_gender = patient_info.get("gender", "N/A")
        patient_blood = patient_info.get("blood_group", "N/A")
        patient_allergies = patient_info.get("allergies", "None reported")

        info_data = [
            [Paragraph("<b>Name:</b>", styles["FieldLabel"]),
             Paragraph(str(patient_name), styles["FieldValue"]),
             Paragraph("<b>Age:</b>", styles["FieldLabel"]),
             Paragraph(str(patient_age), styles["FieldValue"])],
            [Paragraph("<b>Gender:</b>", styles["FieldLabel"]),
             Paragraph(str(patient_gender), styles["FieldValue"]),
             Paragraph("<b>Blood Group:</b>", styles["FieldLabel"]),
             Paragraph(str(patient_blood), styles["FieldValue"])],
            [Paragraph("<b>Allergies:</b>", styles["FieldLabel"]),
             Paragraph(str(patient_allergies), styles["FieldValue"]),
             Paragraph("<b>Date:</b>", styles["FieldLabel"]),
             Paragraph(datetime.now().strftime("%d %b %Y, %I:%M %p"), styles["FieldValue"])],
        ]

        info_table = Table(info_data, colWidths=[70, 160, 70, 160])
        info_table.setStyle(TableStyle([
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]))
        elements.append(info_table)
        elements.append(Spacer(1, 4 * mm))

        # ─── Symptoms ───────────────────────────────────
        elements.append(Paragraph("REPORTED SYMPTOMS", styles["SectionHeader"]))
        elements.append(Paragraph(symptoms, styles["FieldValue"]))

        # ─── Diagnosis ───────────────────────────────────
        elements.append(Paragraph("AI DIAGNOSIS", styles["SectionHeader"]))
        elements.append(Paragraph(f"<b>Predicted Disease:</b> {disease}", styles["FieldValue"]))

        # ─── Medicines ───────────────────────────────────
        elements.append(Paragraph("PRESCRIBED MEDICINES", styles["SectionHeader"]))
        if medicines:
            for med in str(medicines).split(","):
                med = med.strip()
                if med:
                    elements.append(Paragraph(f"• {med}", styles["BulletItem"]))
        else:
            elements.append(Paragraph("• Consult a doctor for medication", styles["BulletItem"]))

        # ─── Precautions ─────────────────────────────────
        elements.append(Paragraph("PRECAUTIONS", styles["SectionHeader"]))
        if isinstance(precautions, list):
            for p in precautions:
                elements.append(Paragraph(f"• {p}", styles["BulletItem"]))
        else:
            elements.append(Paragraph(f"• {precautions}", styles["BulletItem"]))

        # ─── Recommended Tests ───────────────────────────
        elements.append(Paragraph("RECOMMENDED TESTS", styles["SectionHeader"]))
        if isinstance(tests, list):
            for t in tests:
                elements.append(Paragraph(f"• {t}", styles["BulletItem"]))
        else:
            elements.append(Paragraph(f"• {tests}", styles["BulletItem"]))

        # ─── Doctor Notes ────────────────────────────────
        if doctor_notes:
            elements.append(Paragraph("DOCTOR'S NOTES", styles["SectionHeader"]))
            elements.append(Paragraph(doctor_notes, styles["FieldValue"]))

        # ─── Disclaimer ─────────────────────────────────
        elements.append(HRFlowable(width="100%", thickness=0.5, color=GREY))
        elements.append(Paragraph(
            "This is an AI-generated prescription for reference only. "
            "Please consult a qualified healthcare professional before starting any treatment.",
            styles["Disclaimer"]
        ))

        # Build PDF
        doc.build(elements)
        pdf_bytes = buffer.getvalue()
        buffer.close()

        # Upload to Supabase Storage
        file_name = f"prescription_{prescription_id}.pdf"

        # Upload file
        supabase_admin.storage.from_("prescriptions").upload(
            path=file_name,
            file=pdf_bytes,
            file_options={"content-type": "application/pdf", "upsert": "true"}
        )

        # Get public URL
        public_url = supabase_admin.storage.from_("prescriptions").get_public_url(file_name)

        return public_url

    except Exception as e:
        print(f"PDF generation error: {e}")
        return None
