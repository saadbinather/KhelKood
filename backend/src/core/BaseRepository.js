/**
 * BaseRepository - Abstract Base Class for Data Access Layer
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only database operations
 * 2. Open/Closed: Open for extension (subclasses), closed for modification
 * 3. Dependency Inversion: Depends on abstraction (db interface), not concrete implementation
 */

export class BaseRepository {
  constructor(db, collectionName) {
    if (new.target === BaseRepository) {
      throw new Error("Cannot instantiate abstract class BaseRepository");
    }
    this.db = db;
    this.collectionName = collectionName;
  }

  /**
   * Find a document by ID
   * @param {string} id - Document ID
   * @returns {Promise<Object|null>}
   */
  async findById(id) {
    try {
      const docRef = this.db.collection(this.collectionName).doc(id);
      const doc = await docRef.get();
      return doc.exists ? { id: doc.id, ...doc.data() } : null;
    } catch (error) {
      throw new Error(`Error finding ${this.collectionName} by ID: ${error.message}`);
    }
  }

  /**
   * Create a new document
   * @param {Object} data - Data to create
   * @returns {Promise<Object>}
   */
  async create(data) {
    try {
      const docRef = await this.db.collection(this.collectionName).add({
        ...data,
        createdAt: new Date(),
      });
      return { id: docRef.id, ...data, createdAt: new Date() };
    } catch (error) {
      throw new Error(`Error creating ${this.collectionName}: ${error.message}`);
    }
  }

  /**
   * Update a document
   * @param {string} id - Document ID
   * @param {Object} data - Data to update
   * @returns {Promise<Object>}
   */
  async update(id, data) {
    try {
      const docRef = this.db.collection(this.collectionName).doc(id);
      await docRef.update({
        ...data,
        updatedAt: new Date(),
      });
      return await this.findById(id);
    } catch (error) {
      throw new Error(`Error updating ${this.collectionName}: ${error.message}`);
    }
  }

  /**
   * Delete a document
   * @param {string} id - Document ID
   * @returns {Promise<boolean>}
   */
  async delete(id) {
    try {
      await this.db.collection(this.collectionName).doc(id).delete();
      return true;
    } catch (error) {
      throw new Error(`Error deleting ${this.collectionName}: ${error.message}`);
    }
  }

  /**
   * Find documents by a single field
   * @param {string} field - Field name
   * @param {*} value - Field value
   * @param {number} limit - Optional limit
   * @returns {Promise<Array>}
   */
  async findByField(field, value, limit = null) {
    try {
      let query = this.db.collection(this.collectionName).where(field, "==", value);
      
      if (limit) {
        query = query.limit(limit);
      }

      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      throw new Error(`Error finding ${this.collectionName} by ${field}: ${error.message}`);
    }
  }

  /**
   * Find all documents
   * @returns {Promise<Array>}
   */
  async findAll() {
    try {
      const snapshot = await this.db.collection(this.collectionName).get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      throw new Error(`Error finding all ${this.collectionName}: ${error.message}`);
    }
  }

  /**
   * Find with complex query
   * @param {Function} queryBuilder - Function that builds the query
   * @returns {Promise<Array>}
   */
  async findWithQuery(queryBuilder) {
    try {
      const query = queryBuilder(this.db.collection(this.collectionName));
      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      throw new Error(`Error executing query on ${this.collectionName}: ${error.message}`);
    }
  }
}

