-- ============================================================================
-- File: 02_create_tables_user_management.sql
-- Description: Tạo các bảng quản lý người dùng, relationships, emergency contacts
-- Tables: users, user_relationships, emergency_contacts
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- Table: users
-- Purpose: Lưu trữ thông tin tất cả người dùng (bệnh nhân, caregiver, admin)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    
    -- Authentication
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    
    -- Profile
    full_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'other')),
    avatar_url TEXT,
    
    -- Role & Status
    role VARCHAR(20) NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'caregiver', 'admin')),
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    
    -- Medical Info (for patients)
    blood_type VARCHAR(5) CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    height_cm SMALLINT CHECK (height_cm > 0 AND height_cm < 300),
    weight_kg DECIMAL(5,2) CHECK (weight_kg > 0 AND weight_kg < 500),
    medical_conditions TEXT[],  -- Array: ['hypertension', 'diabetes']
    medications TEXT[],
    allergies TEXT[],
    
    -- Preferences
    language VARCHAR(10) DEFAULT 'vi',
    timezone VARCHAR(50) DEFAULT 'Asia/Ho_Chi_Minh',
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ  -- Soft delete for GDPR compliance
);

-- Add comments
COMMENT ON TABLE users IS 'Bảng lưu trữ thông tin người dùng (bệnh nhân, người giám sát, admin)';
COMMENT ON COLUMN users.uuid IS 'UUID public cho API (không expose internal ID)';
COMMENT ON COLUMN users.medical_conditions IS 'Danh sách bệnh lý (hypertension, diabetes, etc.)';
COMMENT ON COLUMN users.deleted_at IS 'Soft delete timestamp (GDPR compliance)';

-- ============================================================================
-- Table: user_relationships
-- Purpose: Quản lý mối quan hệ many-to-many giữa bệnh nhân và caregiver
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_relationships (
    id SERIAL PRIMARY KEY,
    patient_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caregiver_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Relationship
    relationship_type VARCHAR(50) CHECK (relationship_type IN ('family', 'friend', 'doctor', 'nurse', 'other')),
    is_primary BOOLEAN DEFAULT false,  -- Primary emergency contact
    
    -- Permissions (GDPR - fine-grained access control)
    can_view_vitals BOOLEAN DEFAULT true,
    can_receive_alerts BOOLEAN DEFAULT true,
    can_view_location BOOLEAN DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    -- Constraint: Unique relationship pair
    CONSTRAINT unique_patient_caregiver UNIQUE(patient_id, caregiver_id),
    
    -- Constraint: Patient and caregiver must be different
    CONSTRAINT different_users CHECK (patient_id != caregiver_id)
);

COMMENT ON TABLE user_relationships IS 'Mối quan hệ bệnh nhân - người giám sát (nhiều-nhiều)';
COMMENT ON COLUMN user_relationships.is_primary IS 'Người liên hệ khẩn cấp chính (gọi đầu tiên khi SOS)';
COMMENT ON COLUMN user_relationships.can_view_location IS 'Quyền xem vị trí GPS thời gian thực';

-- ============================================================================
-- Table: emergency_contacts
-- Purpose: Lưu số điện thoại khẩn cấp (có thể là người ngoài hệ thống)
-- ============================================================================
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Contact Info
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(50),  -- 'spouse', 'child', 'doctor'
    
    -- Priority (1 = call first)
    priority SMALLINT DEFAULT 1 CHECK (priority > 0),
    
    -- Notification Preferences
    notify_via_sms BOOLEAN DEFAULT true,
    notify_via_call BOOLEAN DEFAULT false,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE emergency_contacts IS 'Danh bạ khẩn cấp (có thể là người ngoài hệ thống)';
COMMENT ON COLUMN emergency_contacts.priority IS 'Thứ tự gọi khi SOS (1 = ưu tiên cao nhất)';

-- ============================================================================
-- Create function to auto-update updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to users table
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created table: users';
    RAISE NOTICE '✓ Created table: user_relationships';
    RAISE NOTICE '✓ Created table: emergency_contacts';
    RAISE NOTICE '✓ Created triggers for auto-update timestamps';
END $$;
