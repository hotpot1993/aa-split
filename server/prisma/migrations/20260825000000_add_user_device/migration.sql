-- CreateTable
CREATE TABLE "user_devices" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "device_id" VARCHAR(64) NOT NULL,
    "platform" VARCHAR(16) NOT NULL DEFAULT '',
    "device_name" VARCHAR(64) NOT NULL DEFAULT '',
    "os_version" VARCHAR(32) NOT NULL DEFAULT '',
    "ip" VARCHAR(45),
    "last_login_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_devices_user_id_device_id_key" ON "user_devices"("user_id", "device_id");

-- CreateIndex
CREATE INDEX "user_devices_user_id_idx" ON "user_devices"("user_id");

-- AddForeignKey
ALTER TABLE "user_devices" ADD CONSTRAINT "user_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
