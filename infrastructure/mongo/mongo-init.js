// Mongo initialization script
db = db.getSiblingDB(process.env.MONGO_DEFAULT_DB || 'app_db');

print("✅ Initialized default database: " + db.getName());
