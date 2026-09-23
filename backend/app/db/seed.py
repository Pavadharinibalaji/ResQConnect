import asyncio
import logging
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.auth import Role
from app.models.incidents import Incident

logger = logging.getLogger("resqconnect.seed")

ROLES = [
    {"name": "citizen", "description": "Standard citizen user account"},
    {"name": "volunteer", "description": "Community responder volunteer"},
    {"name": "ngo", "description": "Non-governmental emergency organization"},
    {"name": "police", "description": "Police department responder"},
    {"name": "fire", "description": "Fire and rescue department responder"},
    {"name": "ambulance", "description": "Medical emergency responder"},
    {"name": "admin", "description": "System administrator account"},
]

SAMPLE_INCIDENTS = [
    {
        "title": "Structure Fire - Residential Building",
        "description": "Active residential fire on 3rd floor. Evacuation in progress.",
        "category": "fire",
        "severity": "critical",
        "status": "reported",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "address": "742 Market Street, San Francisco, CA"
    },
    {
        "title": "Medical Emergency - Cardiac Arrest",
        "description": "Male, 55 years old, unresponsive. CPR initiated by bystander.",
        "category": "medical",
        "severity": "critical",
        "status": "in_progress",
        "latitude": 37.7833,
        "longitude": -122.4167,
        "address": "101 Powell St, San Francisco, CA"
    },
    {
        "title": "Flash Flood Road Blockade",
        "description": "Water accumulation rendering main intersection impassable.",
        "category": "flood",
        "severity": "medium",
        "status": "reported",
        "latitude": 37.7690,
        "longitude": -122.4480,
        "address": "Fell St & Laguna St, San Francisco, CA"
    }
]

async def seed_database():
    async with AsyncSessionLocal() as session:
        # 1. Seed Roles
        for role_data in ROLES:
            stmt = select(Role).where(Role.name == role_data["name"])
            res = await session.execute(stmt)
            existing = res.scalars().first()
            if not existing:
                role = Role(name=role_data["name"], description=role_data["description"])
                session.add(role)
                logger.info(f"Seeded role: {role_data['name']}")

        # 2. Seed Sample Incidents
        stmt = select(Incident)
        res = await session.execute(stmt)
        existing_incidents = res.scalars().all()
        if not existing_incidents:
            for inc in SAMPLE_INCIDENTS:
                incident = Incident(**inc)
                session.add(incident)
                logger.info(f"Seeded sample incident: {inc['title']}")

        await session.commit()
        logger.info("Database seeding completed successfully.")

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(seed_database())
