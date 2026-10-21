import csv
import io
from datetime import date, timedelta

from flask import Blueprint, jsonify, request, Response
from flask_jwt_extended import jwt_required, get_jwt_identity

from .factors import UNITS
from .models import Activity
from .stats import get_stats, PERIOD_DAYS, GOOD_DAILY_CO2, POOR_DAILY_CO2

reports_bp = Blueprint('reports', __name__, url_prefix='/api/reports')


def _uid():
    return int(get_jwt_identity())


def _period_window():
    """Rolling window ending today. Returns (period, start, end) or (None, err)."""
    period = (request.args.get('period') or 'month').strip().lower()
    if period not in PERIOD_DAYS:
        return None, "period must be 'week' or 'month'"
    days = PERIOD_DAYS[period]
    end = date.today()
    return (period, end - timedelta(days=days - 1), end), None


def _pdf_escape(text):
    return (
        str(text)
        .replace('\\', r'\\')
        .replace('(', r'\(')
        .replace(')', r'\)')
    )


def _build_pdf(lines):
    """Render a one-page PDF from a list of text lines. No external deps."""
    parts = []
    parts.append("BT")
    parts.append("/F1 16 Tf")
    parts.append("50 760 Td")
    first = True
    for line in lines:
        if first:
            first = False
        else:
            parts.append("0 -18 Td")
        parts.append("(%s) Tj" % _pdf_escape(line))
    parts.append("ET")
    content = "\n".join(parts).encode("latin-1", "replace")

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        b"<< /Length %d >>\nstream\n" % len(content) + content + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]

    out = io.BytesIO()
    out.write(b"%PDF-1.4\n")
    offsets = []
    for i, body in enumerate(objects, start=1):
        offsets.append(out.tell())
        out.write(b"%d 0 obj\n" % i + body + b"\nendobj\n")
    xref_pos = out.tell()
    out.write(b"xref\n0 %d\n" % (len(objects) + 1))
    out.write(b"0000000000 65535 f \n")
    for off in offsets:
        out.write(b"%010d 00000 n \n" % off)
    out.write(b"trailer\n<< /Size %d /Root 1 0 R >>\n" % (len(objects) + 1))
    out.write(b"startxref\n%d\n%%%%EOF" % xref_pos)
    return out.getvalue()


@reports_bp.get('/monthly')
@jwt_required()
def monthly():
    uid = _uid()
    now = date.today()
    start = date(now.year, now.month, 1)
    if now.month == 12:
        end = date(now.year + 1, 1, 1) - timedelta(days=1)
    else:
        end = date(now.year, now.month + 1, 1) - timedelta(days=1)
    by_cat, daily, total, active = get_stats(uid, start, end)
    return jsonify({
        'period': f'{now.year}-{now.month:02d}',
        'start': str(start),
        'end': str(end),
        'by_category': by_cat,
        'daily': daily,
        'total_co2_kg': total,
        'active_days': active,
    })


@reports_bp.get('/activities.csv')
@jwt_required()
def activities_csv():
    window, err = _period_window()
    if err:
        return jsonify(error=err), 400
    period, start, end = window

    rows = (
        Activity.query
        .filter(Activity.user_id == _uid(), Activity.date >= start, Activity.date <= end)
        .order_by(Activity.date.asc(), Activity.id.asc())
        .all()
    )

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(['date', 'category', 'type', 'quantity', 'unit', 'co2_kg'])
    for a in rows:
        writer.writerow([
            a.date.isoformat(), a.category, a.type,
            round(float(a.quantity), 4), UNITS.get(a.category, ''),
            round(float(a.co2_kg), 4),
        ])

    return Response(
        buf.getvalue(),
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename="ecotrack-{period}.csv"'},
    )


@reports_bp.get('/summary.pdf')
@jwt_required()
def summary_pdf():
    window, err = _period_window()
    if err:
        return jsonify(error=err), 400
    period, start, end = window
    by_cat, _daily, total, active = get_stats(_uid(), start, end)

    avg = round(total / active, 2) if active else 0.0
    lines = [
        'EcoTrack Sustainability Report',
        f'Period: {period} ({start.isoformat()} to {end.isoformat()})',
        '',
        f'Total CO2: {total} kg',
        f'Active days: {active}',
        f'Average per active day: {avg} kg',
        '',
        'Breakdown by category:',
    ]
    for cat, entry in by_cat.items():
        lines.append(f'  - {cat}: {entry["co2_kg"]} kg ({entry["entries"]} entries)')
    lines += [
        '',
        f'Score thresholds: 100 at <= {GOOD_DAILY_CO2} kg/day; '
        f'0 at >= {POOR_DAILY_CO2} kg/day',
    ]

    pdf = _build_pdf(lines)
    return Response(
        pdf,
        mimetype='application/pdf',
        headers={'Content-Disposition': 'attachment; filename="ecotrack-report.pdf"'},
    )
