import re

with open(r'C:\Dev\Project2\health_system\backend\app\repositories\emergency_repository.py', 'r', encoding='utf-8') as f:
    text = f.read()

pattern = r'(query = db\.query\(SOSEvent\)\.filter\(\s+or_\(.*?\)\n        \)\n)(.*?)(        # Get paginated results, ordered by most recent first)'
match = re.search(pattern, text, re.DOTALL)

if match:
    new_query = '''        caregiver_rel_exists = exists().where(
            and_(
                UserRelationship.caregiver_id == caregiver_user_id,
                UserRelationship.patient_id == SOSEvent.user_id,
                UserRelationship.status == "accepted",
                SOSEvent.triggered_at >= UserRelationship.created_at
            )
        )
        patient_rel_exists = exists().where(
            and_(
                UserRelationship.patient_id == caregiver_user_id,
                UserRelationship.caregiver_id == SOSEvent.user_id,
                UserRelationship.status == "accepted",
                SOSEvent.triggered_at >= UserRelationship.created_at
            )
        )

        base_filter = or_(caregiver_rel_exists, patient_rel_exists)

        query = db.query(SOSEvent).filter(base_filter)
'''
    middle = '''
        # Apply status filter
        if status_filter == "active":
            query = query.filter(SOSEvent.status == 'active')
        elif status_filter == "resolved":
            query = query.filter(SOSEvent.status == 'resolved')
        # "all" = no filter

        # Get counts
        total_count = query.count()
        active_count = db.query(func.count(SOSEvent.id)).filter(
            base_filter,
            SOSEvent.status == 'active'
        ).scalar()
        resolved_count = db.query(func.count(SOSEvent.id)).filter(
            base_filter,
            SOSEvent.status == 'resolved'
        ).scalar()
'''
    new_text = text[:match.start()] + new_query + middle + match.group(3) + text[match.end():]
    with open(r'C:\Dev\Project2\health_system\backend\app\repositories\emergency_repository.py', 'w', encoding='utf-8') as f:
        f.write(new_text)
    print("Done")
else:
    print("Not match")
