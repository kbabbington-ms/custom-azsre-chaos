import { MongoClient, Collection } from 'mongodb';
import { ActivityEntry } from '../types';

const MONGO_URI = process.env.MONGO_URI || 'mongodb://mongodb.pets.svc.cluster.local:27017';
const DB_NAME = 'chaosportal';
const COLLECTION = 'activities';

let client: MongoClient | null = null;
let collection: Collection<ActivityEntry> | null = null;

async function getCollection(): Promise<Collection<ActivityEntry>> {
  if (collection) return collection;

  client = new MongoClient(MONGO_URI, {
    serverSelectionTimeoutMS: 3000,
    connectTimeoutMS: 3000,
  });
  await client.connect();
  const db = client.db(DB_NAME);
  collection = db.collection<ActivityEntry>(COLLECTION);

  // Index for efficient queries sorted by timestamp
  await collection.createIndex({ timestamp: -1 });

  console.log(`Connected to MongoDB: ${MONGO_URI}/${DB_NAME}`);
  return collection;
}

export async function logActivity(
  scenario: string,
  message: string,
  level: ActivityEntry['level'] = 'info',
): Promise<ActivityEntry> {
  const entry: ActivityEntry = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    timestamp: new Date().toISOString(),
    scenario,
    message,
    level,
  };

  try {
    const col = await getCollection();
    await col.insertOne({ ...entry });
  } catch (err) {
    console.warn('Failed to persist activity (MongoDB may be unavailable):', err);
  }

  return entry;
}

export async function getActivities(limit = 200): Promise<ActivityEntry[]> {
  try {
    const col = await getCollection();
    return await col.find({}, { projection: { _id: 0 } })
      .sort({ timestamp: -1 })
      .limit(limit)
      .toArray() as unknown as ActivityEntry[];
  } catch (err) {
    console.warn('Failed to read activities (MongoDB may be unavailable):', err);
    return [];
  }
}
