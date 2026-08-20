// Mongo initialization script
db = db.getSiblingDB(process.env.MONGO_DEFAULT_DB || 'sowfkun_verse');

print("✅ Initialized default database: " + db.getName());
