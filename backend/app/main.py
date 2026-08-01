from __future__ import annotations

import base64
import hashlib
import hmac
import os
import re
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .config import get_settings
from .supabase_client import get_supabase_client


app = FastAPI(title="MO'ASHIR API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:8000",
        "http://localhost:8000",
    ],
    allow_origin_regex=r"http://(127\.0\.0\.1|localhost):\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RegisterRequest(BaseModel):
    full_name: str
    national_id: str
    mobile: str
    email: str
    date_of_birth: str
    gender: str
    password: str


class RegisterDoctorRequest(BaseModel):
    full_name: str
    national_id: str
    mobile: str
    email: str
    specialty: str
    degree: str
    years_experience: int
    clinic_name: str | None = None
    working_start: str = "09:00 AM"
    working_end: str = "05:00 PM"
    working_days: list[str] = ["Su", "Mo", "Tu", "We", "Th"]
    languages: list[str] = ["English", "Arabic"]
    certificates: list[str] = []
    accepting_appointments: bool = True
    password: str


class LoginRequest(BaseModel):
    role: str
    method: str
    identifier: str
    password: str


class CreateAppointmentRequest(BaseModel):
    patient_id: str
    doctor_name: str
    date_label: str
    time_label: str
    reason: str
    notes: str | None = None
    visit_mode: str = "in_clinic"
    ctas_level: int | None = None


class CreateMessageRequest(BaseModel):
    patient_id: str
    doctor_id: str
    sender_role: str
    body: str


class CreateMedicationRequest(BaseModel):
    name: str
    dose: str | None = None
    schedule: str | None = None
    active: bool = True
    delivery_status: str = "out_for_delivery"


class CreateVitalRequest(BaseModel):
    vital_type: str
    value: str
    source: str = "app"


class CreateVitalsRequest(BaseModel):
    appointment_id: str | None = None
    vitals: list[CreateVitalRequest]


class UpdateAppointmentStatusRequest(BaseModel):
    status: str


class UpdateVitalApprovalRequest(BaseModel):
    approval_status: str


class DemoFahadAccountTemperatureRequest(BaseModel):
    temperature_c: float
    captured_at: str | None = None
    confidence: str | None = None


class HospitalStationTemperatureRequest(BaseModel):
    patient_id: str
    appointment_id: str | None = None
    temperature_c: float
    captured_at: str | None = None
    confirmation: str | None = None


@app.get("/health")
def health() -> dict[str, Any]:
    settings = get_settings()
    return {
        "status": "ok",
        "supabase_configured": settings.supabase_configured,
        "service_role_configured": settings.service_role_configured,
        "database_url_configured": settings.database_url_configured,
    }


@app.get("/api/doctors")
def list_doctors() -> dict[str, Any]:
    client = _public_client()
    try:
        response = (
            client.table("doctor_profiles")
            .select(
                "id, full_name, specialty, degree, rating, years_experience, "
                "clinic_name, is_online, working_start, working_end, "
                "working_days, languages, certificates"
            )
            .order("full_name")
            .execute()
        )
    except Exception as exc:
        return {"doctors": _demo_doctors()}

    return {"doctors": response.data or []}


@app.get("/api/doctors/{doctor_id}/appointments")
def list_doctor_appointments(doctor_id: str) -> dict[str, Any]:
    client = _service_client()
    try:
        appointment_response = (
            client.table("appointments")
            .select(
                "id, patient_id, doctor_id, appointment_at, date_label, time_label, "
                "reason, notes, visit_mode, ctas_level, status"
            )
            .eq("doctor_id", doctor_id)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not read doctor appointments from Supabase.",
        ) from exc

    appointments = []
    for appointment in appointment_response.data or []:
        patient = _load_patient_by_id(client, appointment["patient_id"])
        appointments.append(
            {
                **_appointment_payload(
                    appointment, _load_doctor_by_id(client, appointment["doctor_id"])
                ),
                "patient": patient,
            }
        )
    return {"appointments": appointments}


@app.post("/api/auth/register")
def register_patient(payload: RegisterRequest) -> dict[str, Any]:
    client = _service_client()
    full_name = payload.full_name.strip()
    national_id = _normalize_text(payload.national_id)
    mobile = _normalize_mobile(payload.mobile)
    email = _normalize_email(payload.email)
    gender = _normalize_gender(payload.gender)
    date_of_birth = _normalize_date(payload.date_of_birth)

    if len(full_name) < 2:
        raise HTTPException(status_code=422, detail="Full name is required.")
    if len(payload.password) < 8:
        raise HTTPException(
            status_code=422, detail="Password must be at least 8 characters."
        )
    if not national_id:
        raise HTTPException(status_code=422, detail="National ID is required.")
    if not mobile:
        raise HTTPException(status_code=422, detail="Mobile number is required.")
    if not email or "@" not in email:
        raise HTTPException(status_code=422, detail="Valid email is required.")

    existing = _find_existing_user(
        client,
        role="patient",
        email=email,
        mobile=mobile,
        national_id=national_id,
    )
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="An account already exists with this mobile, email, or national ID.",
        )

    try:
        patient_response = (
            client.table("patient_profiles")
            .insert(
                {
                    "full_name": full_name,
                    "email": email,
                    "phone": mobile,
                    "national_id": national_id,
                    "date_of_birth": date_of_birth,
                    "gender": gender,
                }
            )
            .execute()
        )
        patient = patient_response.data[0]

        account_response = (
            client.table("user_accounts")
            .insert(
                {
                    "role": "patient",
                    "patient_id": patient["id"],
                    "email": email,
                    "mobile": mobile,
                    "national_id": national_id,
                    "password_hash": _hash_password(payload.password),
                }
            )
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not create account in Supabase.",
        ) from exc

    account = account_response.data[0]
    return {
        "user": _public_account(account),
        "profile": patient,
    }


@app.post("/api/auth/register-doctor")
def register_doctor(payload: RegisterDoctorRequest) -> dict[str, Any]:
    client = _service_client()
    full_name = payload.full_name.strip()
    national_id = _normalize_text(payload.national_id)
    mobile = _normalize_mobile(payload.mobile)
    email = _normalize_email(payload.email)
    specialty = payload.specialty.strip()
    degree = payload.degree.strip()
    clinic_name = (payload.clinic_name or "").strip() or None
    languages = _clean_text_list(payload.languages)
    certificates = _clean_text_list(payload.certificates)
    working_days = _clean_text_list(payload.working_days)

    if len(full_name) < 2:
        raise HTTPException(status_code=422, detail="Full name is required.")
    if not specialty:
        raise HTTPException(status_code=422, detail="Specialty is required.")
    if not degree:
        raise HTTPException(status_code=422, detail="Degree is required.")
    if payload.years_experience < 0 or payload.years_experience > 70:
        raise HTTPException(
            status_code=422, detail="Years of experience must be realistic."
        )
    if len(payload.password) < 8:
        raise HTTPException(
            status_code=422, detail="Password must be at least 8 characters."
        )
    if not national_id:
        raise HTTPException(status_code=422, detail="National ID is required.")
    if not mobile:
        raise HTTPException(status_code=422, detail="Mobile number is required.")
    if not email or "@" not in email:
        raise HTTPException(status_code=422, detail="Valid email is required.")
    if not working_days:
        raise HTTPException(status_code=422, detail="Select at least one working day.")

    existing = _find_existing_user(
        client,
        role="doctor",
        email=email,
        mobile=mobile,
        national_id=national_id,
    )
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="A doctor account already exists with this mobile, email, or national ID.",
        )

    try:
        doctor_response = (
            client.table("doctor_profiles")
            .insert(
                {
                    "full_name": full_name,
                    "specialty": specialty,
                    "degree": degree,
                    "years_experience": payload.years_experience,
                    "clinic_name": clinic_name,
                    "is_online": payload.accepting_appointments,
                    "working_start": payload.working_start.strip(),
                    "working_end": payload.working_end.strip(),
                    "working_days": working_days,
                    "languages": languages,
                    "certificates": certificates,
                }
            )
            .execute()
        )
        doctor = doctor_response.data[0]

        account_response = (
            client.table("user_accounts")
            .insert(
                {
                    "role": "doctor",
                    "doctor_id": doctor["id"],
                    "email": email,
                    "mobile": mobile,
                    "national_id": national_id,
                    "password_hash": _hash_password(payload.password),
                }
            )
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not create doctor account in Supabase.",
        ) from exc

    account = account_response.data[0]
    return {
        "user": _public_account(account),
        "profile": doctor,
    }


@app.post("/api/auth/login")
def login(payload: LoginRequest) -> dict[str, Any]:
    client = _service_client()
    role = _normalize_role(payload.role)
    method = _normalize_login_method(payload.method)
    identifier = _normalize_identifier(method, payload.identifier)

    if not identifier or not payload.password:
        raise HTTPException(status_code=422, detail="Identifier and password are required.")

    try:
        account = _find_user_for_login(client, role, method, identifier)
    except Exception as exc:
        if _is_demo_admin_login(role, method, identifier, payload.password):
            return _demo_admin_session()
        raise exc
    if account is None or not _verify_password(payload.password, account["password_hash"]):
        if _is_demo_admin_login(role, method, identifier, payload.password):
            return _demo_admin_session()
        raise HTTPException(status_code=401, detail="Invalid sign in details.")

    profile = _load_profile(client, account)
    return {
        "user": _public_account(account),
        "profile": profile,
    }


@app.get("/api/patients")
def list_patients() -> dict[str, Any]:
    client = _service_client()
    try:
        response = (
            client.table("patient_profiles")
            .select(
                "id, full_name, gender, date_of_birth, blood_type, "
                "email, phone, national_id"
            )
            .order("full_name")
            .execute()
        )
    except Exception as exc:
        return {"patients": _demo_patients()}

    return {"patients": response.data or []}


@app.get("/api/patients/{patient_id}/appointments")
def list_patient_appointments(patient_id: str) -> dict[str, Any]:
    client = _service_client()
    try:
        appointment_response = (
            client.table("appointments")
            .select(
                "id, doctor_id, appointment_at, date_label, time_label, reason, "
                "notes, visit_mode, ctas_level, status"
            )
            .eq("patient_id", patient_id)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not read patient appointments from Supabase.",
        ) from exc

    appointments = []
    for appointment in appointment_response.data or []:
        appointments.append(
            _appointment_payload(
                appointment, _load_doctor_by_id(client, appointment["doctor_id"])
            )
        )
    return {"appointments": appointments}


@app.get("/api/patients/{patient_id}/medications")
def list_patient_medications(patient_id: str) -> dict[str, Any]:
    client = _service_client()
    try:
        try:
            response = (
                client.table("medications")
                .select("id, name, dose, schedule, active, delivery_status, created_at")
                .eq("patient_id", patient_id)
                .eq("active", True)
                .order("created_at", desc=True)
                .execute()
            )
        except Exception:
            response = (
                client.table("medications")
                .select("id, name, dose, schedule, active, created_at")
                .eq("patient_id", patient_id)
                .eq("active", True)
                .order("created_at", desc=True)
                .execute()
            )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not read medications from Supabase.",
        ) from exc

    medications = response.data or []
    for medication in medications:
        medication.setdefault("delivery_status", "out_for_delivery")
    return {"medications": medications}


@app.post("/api/patients/{patient_id}/medications")
def create_patient_medication(
    patient_id: str, payload: CreateMedicationRequest
) -> dict[str, Any]:
    client = _service_client()
    medication_name = payload.name.strip()
    delivery_status = payload.delivery_status.strip().lower()
    if not medication_name:
        raise HTTPException(status_code=422, detail="Medication name is required.")
    if delivery_status not in {
        "preparing_delivery",
        "out_for_delivery",
        "delivered",
        "cancelled",
    }:
        raise HTTPException(status_code=422, detail="Invalid delivery status.")

    patient_response = (
        client.table("patient_profiles")
        .select("id")
        .eq("id", patient_id.strip())
        .limit(1)
        .execute()
    )
    if not patient_response.data:
        raise HTTPException(status_code=404, detail="Patient not found.")

    try:
        normalized_patient_id = patient_id.strip()
        dose = (payload.dose or "").strip() or None
        schedule = (payload.schedule or "").strip() or None

        if payload.active:
            existing_response = (
                client.table("medications")
                .select("id, name, dose, schedule, active, created_at")
                .eq("patient_id", normalized_patient_id)
                .eq("name", medication_name)
                .eq("active", True)
                .order("created_at", desc=True)
                .limit(10)
                .execute()
            )
            existing_medication = next(
                (
                    item
                    for item in existing_response.data or []
                    if (item.get("dose") or "") == (dose or "")
                ),
                None,
            )
            if existing_medication is not None:
                updates = {
                    "schedule": schedule,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                    "delivery_status": delivery_status,
                }
                try:
                    response = (
                        client.table("medications")
                        .update(updates)
                        .eq("id", existing_medication["id"])
                        .execute()
                    )
                except Exception:
                    response = (
                        client.table("medications")
                        .update(
                            {
                                key: value
                                for key, value in updates.items()
                                if key != "delivery_status"
                            }
                        )
                        .eq("id", existing_medication["id"])
                        .execute()
                    )
                medication = (response.data or [existing_medication])[0]
                medication.setdefault("delivery_status", delivery_status)
                return {"medication": medication}

        row = {
            "patient_id": normalized_patient_id,
            "name": medication_name,
            "dose": dose,
            "schedule": schedule,
            "active": payload.active,
            "delivery_status": delivery_status,
        }
        try:
            response = client.table("medications").insert(row).execute()
        except Exception:
            response = (
                client.table("medications")
                .insert({key: value for key, value in row.items() if key != "delivery_status"})
                .execute()
            )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save medication in Supabase.",
        ) from exc

    medication = response.data[0]
    medication.setdefault("delivery_status", delivery_status)
    return {"medication": medication}


@app.get("/api/patients/{patient_id}/vitals")
def list_patient_vitals(
    patient_id: str, appointment_id: str | None = None
) -> dict[str, Any]:
    client = _service_client()
    try:
        query = (
            client.table("patient_vitals")
            .select(
                "id, patient_id, appointment_id, vital_type, value, source, "
                "approval_status, measured_at"
            )
            .eq("patient_id", patient_id)
        )
        normalized_appointment_id = (appointment_id or "").strip()
        if normalized_appointment_id:
            query = query.eq("appointment_id", normalized_appointment_id)
        response = query.order("measured_at", desc=True).execute()
    except Exception as exc:
        return {"vitals": []}

    return {"vitals": response.data or []}


@app.post("/api/patients/{patient_id}/vitals")
def create_patient_vitals(
    patient_id: str, payload: CreateVitalsRequest
) -> dict[str, Any]:
    client = _service_client()
    normalized_patient_id = patient_id.strip()
    appointment_id = (payload.appointment_id or "").strip() or None

    patient_response = (
        client.table("patient_profiles")
        .select("id")
        .eq("id", normalized_patient_id)
        .limit(1)
        .execute()
    )
    if not patient_response.data:
        raise HTTPException(status_code=404, detail="Patient not found.")

    allowed_sources = {"camera", "app", "device", "manual"}
    rows = []
    for vital in payload.vitals:
        vital_type = vital.vital_type.strip()
        value = vital.value.strip()
        source = vital.source.strip().lower()
        if not vital_type or not value:
            continue
        if source not in allowed_sources:
            raise HTTPException(status_code=422, detail="Invalid vital source.")
        if _normalize_vital_name(vital_type) == "temperature":
            raise HTTPException(
                status_code=422,
                detail="Temperature must be captured from the thermal camera endpoint.",
            )
        rows.append(
            {
                "patient_id": normalized_patient_id,
                "appointment_id": appointment_id,
                "vital_type": vital_type,
                "value": value,
                "source": source,
                "approval_status": "pending",
            }
        )

    if not rows:
        raise HTTPException(status_code=422, detail="At least one vital is required.")

    try:
        response = client.table("patient_vitals").insert(rows).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save vitals in Supabase.",
        ) from exc

    return {"vitals": response.data or []}


@app.post("/api/demo/fahad-account/temperature")
def create_demo_fahad_account_temperature(
    payload: DemoFahadAccountTemperatureRequest,
) -> dict[str, Any]:
    client = _service_client()
    if payload.temperature_c < 30 or payload.temperature_c > 45:
        raise HTTPException(status_code=422, detail="Invalid temperature.")

    patient = _load_patient_by_account_email(client, "fahad1@hotmail.com")
    appointment = _load_latest_patient_appointment_by_reason(
        client,
        patient_id=patient["id"],
        reason="fever",
    )
    measured_at = _normalized_measured_at(payload.captured_at)
    try:
        response = (
            client.table("patient_vitals")
            .insert(
                {
                    "patient_id": patient["id"],
                    "appointment_id": appointment["id"] if appointment else None,
                    "vital_type": "Temperature",
                    "value": f"{payload.temperature_c:.1f} C",
                    "source": "camera",
                    "approval_status": "pending",
                    "measured_at": measured_at,
                }
            )
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save Fahad's temperature.",
        ) from exc

    return {"patient": patient, "appointment": appointment, "vital": response.data[0]}


@app.post("/api/hospital-station/temperature")
def create_hospital_station_temperature(
    payload: HospitalStationTemperatureRequest,
) -> dict[str, Any]:
    client = _service_client()
    patient_id = payload.patient_id.strip()
    appointment_id = (payload.appointment_id or "").strip() or None

    if payload.temperature_c < 30 or payload.temperature_c > 45:
        raise HTTPException(status_code=422, detail="Invalid temperature.")

    patient = _load_patient_by_id(client, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found.")

    if appointment_id is not None:
        appointment_response = (
            client.table("appointments")
            .select("id, patient_id")
            .eq("id", appointment_id)
            .eq("patient_id", patient_id)
            .limit(1)
            .execute()
        )
        if not appointment_response.data:
            raise HTTPException(status_code=404, detail="Appointment not found.")

    measured_at = _normalized_measured_at(payload.captured_at)
    try:
        response = (
            client.table("patient_vitals")
            .insert(
                {
                    "patient_id": patient_id,
                    "appointment_id": appointment_id,
                    "vital_type": "Temperature",
                    "value": f"{payload.temperature_c:.1f} C from thermal camera",
                    "source": "camera",
                    "approval_status": "pending",
                    "measured_at": measured_at,
                }
            )
            .execute()
        )
        if appointment_id is not None:
            client.table("appointments").update(
                {
                    "status": "checked_in",
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            ).eq("id", appointment_id).eq("patient_id", patient_id).execute()
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save hospital station temperature.",
        ) from exc

    return {"patient": patient, "vital": response.data[0], "status": "checked_in"}


@app.get("/api/patients/{patient_id}/appointments/upcoming")
def get_upcoming_appointment(patient_id: str) -> dict[str, Any]:
    client = _service_client()
    try:
        appointment_response = (
            client.table("appointments")
            .select(
                "id, doctor_id, appointment_at, date_label, time_label, reason, "
                "notes, visit_mode, ctas_level, status"
            )
            .eq("patient_id", patient_id)
            .in_("status", ["scheduled", "checked_in", "in_clinic"])
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not read appointments from Supabase.",
        ) from exc

    if not appointment_response.data:
        return {"appointment": None}

    appointment = appointment_response.data[0]
    doctor = _load_doctor_by_id(client, appointment["doctor_id"])
    return {"appointment": _appointment_payload(appointment, doctor)}


@app.post("/api/appointments")
def create_appointment(payload: CreateAppointmentRequest) -> dict[str, Any]:
    client = _service_client()
    patient_id = payload.patient_id.strip()
    doctor_name = payload.doctor_name.strip()
    reason = payload.reason.strip()

    if not patient_id:
        raise HTTPException(status_code=422, detail="Patient ID is required.")
    if not doctor_name:
        raise HTTPException(status_code=422, detail="Doctor is required.")
    if not reason:
        raise HTTPException(status_code=422, detail="Reason for visit is required.")
    if payload.ctas_level is not None and not 1 <= payload.ctas_level <= 5:
        raise HTTPException(status_code=422, detail="CTAS level must be between 1 and 5.")

    patient_response = (
        client.table("patient_profiles")
        .select("id")
        .eq("id", patient_id)
        .limit(1)
        .execute()
    )
    if not patient_response.data:
        raise HTTPException(status_code=404, detail="Patient not found.")

    doctor = _load_doctor_by_name(client, doctor_name)
    if doctor is None:
        raise HTTPException(status_code=404, detail="Doctor not found.")

    try:
        appointment_response = (
            client.table("appointments")
            .insert(
                {
                    "patient_id": patient_id,
                    "doctor_id": doctor["id"],
                    "appointment_at": datetime.now(timezone.utc).isoformat(),
                    "date_label": payload.date_label.strip(),
                    "time_label": payload.time_label.strip(),
                    "reason": reason,
                    "notes": (payload.notes or "").strip() or None,
                    "visit_mode": payload.visit_mode,
                    "ctas_level": payload.ctas_level,
                    "status": "scheduled",
                }
            )
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save appointment in Supabase.",
        ) from exc

    appointment = appointment_response.data[0]
    return {"appointment": _appointment_payload(appointment, doctor)}


@app.patch("/api/appointments/{appointment_id}/status")
def update_appointment_status(
    appointment_id: str, payload: UpdateAppointmentStatusRequest
) -> dict[str, Any]:
    client = _service_client()
    status = payload.status.strip().lower()
    if status not in {"scheduled", "checked_in", "in_clinic", "completed", "cancelled"}:
        raise HTTPException(status_code=422, detail="Invalid appointment status.")

    try:
        response = (
            client.table("appointments")
            .update({"status": status, "updated_at": datetime.now(timezone.utc).isoformat()})
            .eq("id", appointment_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not update appointment status in Supabase.",
        ) from exc

    if not response.data:
        raise HTTPException(status_code=404, detail="Appointment not found.")

    appointment = response.data[0]
    doctor = _load_doctor_by_id(client, appointment["doctor_id"])
    return {"appointment": _appointment_payload(appointment, doctor)}


@app.patch("/api/vitals/{vital_id}/approval")
def update_vital_approval(
    vital_id: str, payload: UpdateVitalApprovalRequest
) -> dict[str, Any]:
    client = _service_client()
    approval_status = payload.approval_status.strip().lower()
    if approval_status not in {"pending", "confirmed", "retake_requested", "rejected"}:
        raise HTTPException(status_code=422, detail="Invalid vital approval status.")

    try:
        response = (
            client.table("patient_vitals")
            .update({"approval_status": approval_status})
            .eq("id", vital_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not update vital approval in Supabase.",
        ) from exc

    if not response.data:
        raise HTTPException(status_code=404, detail="Vital measurement not found.")

    return {"vital": response.data[0]}


@app.get("/api/messages")
def list_messages(patient_id: str, doctor_id: str) -> dict[str, Any]:
    client = _service_client()
    try:
        response = (
            client.table("messages")
            .select("id, patient_id, doctor_id, sender_role, body, created_at")
            .eq("patient_id", patient_id)
            .eq("doctor_id", doctor_id)
            .order("created_at")
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not read messages from Supabase.",
        ) from exc
    return {"messages": response.data or []}


@app.post("/api/messages")
def create_message(payload: CreateMessageRequest) -> dict[str, Any]:
    client = _service_client()
    sender_role = payload.sender_role.strip().lower()
    body = payload.body.strip()
    if sender_role not in {"patient", "doctor"}:
        raise HTTPException(status_code=422, detail="Sender role must be patient or doctor.")
    if not body:
        raise HTTPException(status_code=422, detail="Message is required.")

    try:
        response = (
            client.table("messages")
            .insert(
                {
                    "patient_id": payload.patient_id.strip(),
                    "doctor_id": payload.doctor_id.strip(),
                    "sender_role": sender_role,
                    "body": body,
                }
            )
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not save message in Supabase.",
        ) from exc

    return {"message": response.data[0]}


@app.post("/api/dev/seed-demo-doctor")
def seed_demo_doctor() -> dict[str, Any]:
    client = _service_client()
    doctor_response = (
        client.table("doctor_profiles")
        .select("id, full_name, specialty")
        .eq("full_name", "Khalid")
        .limit(1)
        .execute()
    )
    if not doctor_response.data:
        doctor_response = (
            client.table("doctor_profiles")
            .insert(
                {
                    "full_name": "Khalid",
                    "specialty": "General Physician",
                    "degree": "MBBS, MD",
                    "years_experience": 10,
                    "working_start": "09:00 AM",
                    "working_end": "07:00 PM",
                    "working_days": ["Mo", "Tu", "We"],
                    "languages": ["English", "Arabic"],
                    "certificates": [
                        "MBBS, MD - Internal Medicine",
                        "Board Certified - Family Medicine (SCFHS)",
                        "Advanced Life Support (ACLS)",
                    ],
                }
            )
            .execute()
        )

    doctor = doctor_response.data[0]
    existing = _find_existing_user(
        client,
        role="doctor",
        email="doctor@example.com",
        mobile="+966500000001",
        national_id="D100000001",
    )
    if existing is not None:
        account_response = (
            client.table("user_accounts")
            .update(
                {
                    "doctor_id": doctor["id"],
                    "mobile": "+966500000001",
                    "national_id": "D100000001",
                    "password_hash": _hash_password("Doctor123!"),
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            )
            .eq("id", existing["id"])
            .execute()
        )
        return {
            "created": False,
            "repaired": True,
            "doctor": doctor,
            "user": _public_account(account_response.data[0]),
            "email": "doctor@example.com",
            "password": "Doctor123!",
        }

    account_response = (
        client.table("user_accounts")
        .insert(
            {
                "role": "doctor",
                "doctor_id": doctor["id"],
                "email": "doctor@example.com",
                "mobile": "+966500000001",
                "national_id": "D100000001",
                "password_hash": _hash_password("Doctor123!"),
            }
        )
        .execute()
    )
    return {
        "created": True,
        "doctor": doctor,
        "user": _public_account(account_response.data[0]),
        "email": "doctor@example.com",
        "password": "Doctor123!",
    }


@app.post("/api/dev/seed-demo-admin")
def seed_demo_admin() -> dict[str, Any]:
    client = _service_client()
    existing = _find_existing_user(
        client,
        role="admin",
        email="admin@example.com",
        mobile="+966500000009",
        national_id="A100000001",
    )
    if existing is not None:
        return {
            "created": False,
            "user": _public_account(existing),
            "email": "admin@example.com",
        }

    try:
        account_response = (
            client.table("user_accounts")
            .insert(
                {
                    "role": "admin",
                    "email": "admin@example.com",
                    "mobile": "+966500000009",
                    "national_id": "A100000001",
                    "password_hash": _hash_password("Admin123!"),
                }
            )
            .execute()
        )
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=(
                "Could not create admin account. Run the updated "
                "supabase/schema.sql first so user_accounts allows role admin."
            ),
        ) from exc

    return {
        "created": True,
        "user": _public_account(account_response.data[0]),
        "email": "admin@example.com",
        "password": "Admin123!",
    }


def _public_client():
    settings = get_settings()
    if not settings.supabase_configured:
        raise HTTPException(
            status_code=503,
            detail="Supabase URL and publishable key are required.",
        )
    return get_supabase_client(use_service_role=False)


def _service_client():
    settings = get_settings()
    if not settings.service_role_configured:
        raise HTTPException(
            status_code=503,
            detail="Supabase service role key is required for backend patient data.",
        )
    return get_supabase_client(use_service_role=True)


def _hash_password(password: str) -> str:
    salt = os.urandom(16)
    iterations = 210_000
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return "$".join(
        [
            "pbkdf2_sha256",
            str(iterations),
            base64.b64encode(salt).decode("ascii"),
            base64.b64encode(digest).decode("ascii"),
        ]
    )


def _verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations_text, salt_text, digest_text = stored_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        iterations = int(iterations_text)
        salt = base64.b64decode(salt_text.encode("ascii"))
        expected = base64.b64decode(digest_text.encode("ascii"))
    except Exception:
        return False

    actual = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt, iterations
    )
    return hmac.compare_digest(actual, expected)


def _normalize_role(role: str) -> str:
    normalized = role.strip().lower()
    if normalized not in {"patient", "doctor", "admin"}:
        raise HTTPException(
            status_code=422, detail="Role must be patient, doctor, or admin."
        )
    return normalized


def _normalize_login_method(method: str) -> str:
    normalized = method.strip().lower().replace("_", "")
    if normalized in {"mobile", "phone"}:
        return "mobile"
    if normalized == "email":
        return "email"
    if normalized in {"nationalid", "national"}:
        return "national_id"
    raise HTTPException(status_code=422, detail="Invalid sign in method.")


def _normalize_identifier(method: str, value: str) -> str:
    if method == "mobile":
        return _normalize_mobile(value)
    if method == "email":
        return _normalize_email(value)
    return _normalize_text(value)


def _normalize_email(value: str) -> str:
    return value.strip().lower()


def _normalize_text(value: str) -> str:
    return value.strip()


def _normalize_mobile(value: str) -> str:
    digits = re.sub(r"\D", "", value)
    if not digits:
        return ""
    if digits.startswith("00966"):
        digits = digits[2:]
    if digits.startswith("966"):
        return f"+{digits}"
    if digits.startswith("05"):
        return f"+966{digits[1:]}"
    if digits.startswith("5") and len(digits) == 9:
        return f"+966{digits}"
    return f"+{digits}" if value.strip().startswith("+") else digits


def _normalize_gender(value: str) -> str:
    gender = value.strip().lower()
    if gender not in {"male", "female"}:
        raise HTTPException(status_code=422, detail="Gender must be male or female.")
    return gender


def _normalize_date(value: str) -> str:
    normalized = value.strip()
    for date_format in ("%Y-%m-%d", "%d/%m/%Y", "%d / %m / %Y"):
        try:
            return datetime.strptime(normalized, date_format).date().isoformat()
        except ValueError:
            continue
    raise HTTPException(
        status_code=422,
        detail="Date of birth must use YYYY-MM-DD or DD/MM/YYYY.",
    )


def _clean_text_list(values: list[str]) -> list[str]:
    cleaned = []
    for value in values:
        item = value.strip()
        if item and item not in cleaned:
            cleaned.append(item)
    return cleaned


def _find_existing_user(
    client, *, role: str, email: str, mobile: str, national_id: str
) -> dict[str, Any] | None:
    checks = (
        ("email", email),
        ("mobile", mobile),
        ("national_id", national_id),
    )
    for column, value in checks:
        if not value:
            continue
        response = (
            client.table("user_accounts")
            .select("id, role, patient_id, doctor_id, email, mobile, national_id")
            .eq("role", role)
            .eq(column, value)
            .limit(1)
            .execute()
        )
        if response.data:
            return response.data[0]
    return None


def _find_user_for_login(
    client, role: str, method: str, identifier: str
) -> dict[str, Any] | None:
    response = (
        client.table("user_accounts")
        .select("*")
        .eq("role", role)
        .eq(method, identifier)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _load_profile(client, account: dict[str, Any]) -> dict[str, Any] | None:
    if account["role"] == "patient":
        response = (
            client.table("patient_profiles")
            .select("*")
            .eq("id", account["patient_id"])
            .limit(1)
            .execute()
        )
    elif account["role"] == "doctor":
        response = (
            client.table("doctor_profiles")
            .select("*")
            .eq("id", account["doctor_id"])
            .limit(1)
            .execute()
        )
    else:
        return {
            "id": account["id"],
            "full_name": "Administrator",
            "email": account.get("email"),
        }
    return response.data[0] if response.data else None


def _load_patient_by_id(client, patient_id: str) -> dict[str, Any] | None:
    response = (
        client.table("patient_profiles")
        .select("id, full_name, email, phone, national_id, date_of_birth, gender, blood_type")
        .eq("id", patient_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _load_patient_by_account_email(client, email: str) -> dict[str, Any]:
    account_response = (
        client.table("user_accounts")
        .select("patient_id")
        .eq("role", "patient")
        .eq("email", email)
        .limit(1)
        .execute()
    )
    if not account_response.data or not account_response.data[0].get("patient_id"):
        raise HTTPException(status_code=404, detail="Fahad account not found.")

    patient = _load_patient_by_id(client, account_response.data[0]["patient_id"])
    if patient is None:
        raise HTTPException(status_code=404, detail="Fahad patient profile not found.")
    return patient


def _load_latest_patient_appointment_by_reason(
    client, *, patient_id: str, reason: str
) -> dict[str, Any] | None:
    response = (
        client.table("appointments")
        .select(
            "id, patient_id, doctor_id, appointment_at, date_label, time_label, "
            "reason, notes, visit_mode, ctas_level, status"
        )
        .eq("patient_id", patient_id)
        .ilike("reason", f"%{reason}%")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _normalized_measured_at(value: str | None) -> str:
    if value and value.strip():
        normalized = value.strip()
        try:
            datetime.fromisoformat(normalized.replace("Z", "+00:00"))
            return normalized
        except ValueError:
            pass
    return datetime.now(timezone.utc).isoformat()


def _normalize_vital_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def _load_doctor_by_name(client, full_name: str) -> dict[str, Any] | None:
    response = (
        client.table("doctor_profiles")
        .select("id, full_name, specialty, degree, rating, years_experience, clinic_name")
        .eq("full_name", full_name)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _load_doctor_by_id(client, doctor_id: str) -> dict[str, Any] | None:
    response = (
        client.table("doctor_profiles")
        .select("id, full_name, specialty, degree, rating, years_experience, clinic_name")
        .eq("id", doctor_id)
        .limit(1)
        .execute()
    )
    return response.data[0] if response.data else None


def _appointment_payload(
    appointment: dict[str, Any], doctor: dict[str, Any] | None
) -> dict[str, Any]:
    return {
        "id": appointment["id"],
        "patient_id": appointment.get("patient_id"),
        "doctor_id": appointment["doctor_id"],
        "doctor_name": doctor["full_name"] if doctor else "Doctor",
        "doctor_specialty": doctor["specialty"] if doctor else "",
        "doctor_degree": doctor.get("degree") if doctor else None,
        "doctor_clinic_name": doctor.get("clinic_name") if doctor else None,
        "date_label": appointment.get("date_label"),
        "time_label": appointment.get("time_label"),
        "appointment_at": appointment.get("appointment_at"),
        "reason": appointment.get("reason"),
        "notes": appointment.get("notes"),
        "visit_mode": appointment.get("visit_mode"),
        "ctas_level": appointment.get("ctas_level"),
        "status": appointment.get("status"),
    }


def _public_account(account: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": account["id"],
        "role": account["role"],
        "patient_id": account.get("patient_id"),
        "doctor_id": account.get("doctor_id"),
        "email": account.get("email"),
        "mobile": account.get("mobile"),
        "national_id": account.get("national_id"),
    }


def _is_demo_admin_login(
    role: str, method: str, identifier: str, password: str
) -> bool:
    expected_identifier = {
        "email": "admin@example.com",
        "mobile": "+966500000009",
        "national_id": "A100000001",
    }.get(method)
    return (
        role == "admin"
        and expected_identifier is not None
        and identifier == expected_identifier
        and password == "Admin123!"
    )


def _demo_admin_session() -> dict[str, Any]:
    account = {
        "id": "demo-hospitel-admin",
        "role": "admin",
        "patient_id": None,
        "doctor_id": None,
        "email": "admin@example.com",
        "mobile": "+966500000009",
        "national_id": "A100000001",
    }
    return {
        "user": account,
        "profile": {
            "id": account["id"],
            "full_name": "Hospitel Demo",
            "email": account["email"],
            "phone": account["mobile"],
            "national_id": account["national_id"],
        },
    }


def _demo_doctors() -> list[dict[str, Any]]:
    return [
        {
            "id": "demo-doctor-1",
            "full_name": "Dr. Ahmed Mohamed",
            "specialty": "General Physician",
            "degree": "MBBS, MD",
            "rating": 4.9,
            "years_experience": 12,
            "clinic_name": "Care Medical Center",
            "is_online": True,
            "working_start": "09:00 AM",
            "working_end": "05:00 PM",
            "working_days": ["Su", "Mo", "Tu", "We", "Th"],
            "languages": ["English", "Arabic"],
            "certificates": [],
        },
        {
            "id": "demo-doctor-2",
            "full_name": "Dr. Sara Al-Harbi",
            "specialty": "Cardiologist",
            "degree": "MBBS, DM Cardio",
            "rating": 4.9,
            "years_experience": 9,
            "clinic_name": "Care Medical Center",
            "is_online": True,
            "working_start": "09:00 AM",
            "working_end": "05:00 PM",
            "working_days": ["Su", "Mo", "Tu", "We", "Th"],
            "languages": ["English", "Arabic"],
            "certificates": [],
        },
    ]


def _demo_patients() -> list[dict[str, Any]]:
    return [
        {
            "id": "demo-patient-1",
            "full_name": "Noura Al-Amri",
            "gender": "female",
            "date_of_birth": "1994-05-18",
            "blood_type": "O+",
            "email": "noura@example.com",
            "phone": "+966500000001",
            "national_id": "P100000001",
        },
        {
            "id": "demo-patient-2",
            "full_name": "Fahad Al-Qahtani",
            "gender": "male",
            "date_of_birth": "1989-11-03",
            "blood_type": "A+",
            "email": "fahad@example.com",
            "phone": "+966500000002",
            "national_id": "P100000002",
        },
    ]
