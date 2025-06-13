from flask import Flask, request, jsonify
import mysql.connector
from mysql.connector import Error
import os

app = Flask(__name__)

def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host=os.getenv('MYSQL_HOST'),
            user=os.getenv('MYSQL_USER'),
            password=os.getenv('MYSQL_PASSWORD'),
            database=os.getenv('MYSQL_DATABASE')
        )
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

@app.route('/users', methods=['POST'])
def create_user():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400

    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            query = "INSERT INTO users (email, password, active) VALUES (%s, %s, %s)"
            cursor.execute(query, (email, password, 1))
            connection.commit()
            return jsonify({'message': 'User created'}), 201
        except Error as e:
            return jsonify({'error': str(e)}), 500
        finally:
            cursor.close()
            connection.close()
    return jsonify({'error': 'Database connection failed'}), 500

@app.route('/users/<email>', methods=['GET'])
def get_user(email):
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            query = "SELECT email, active FROM users WHERE email = %s"
            cursor.execute(query, (email,))
            user = cursor.fetchone()
            if user:
                return jsonify(user), 200
            return jsonify({'error': 'User not found'}), 404
        except Error as e:
            return jsonify({'error': str(e)}), 500
        finally:
            cursor.close()
            connection.close()
    return jsonify({'error': 'Database connection failed'}), 500

@app.route('/users/<email>', methods=['PUT'])
def update_user(email):
    data = request.get_json()
    password = data.get('password')
    active = data.get('active', 1)

    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            query = "UPDATE users SET password = %s, active = %s WHERE email = %s"
            cursor.execute(query, (password, active, email))
            connection.commit()
            if cursor.rowcount:
                return jsonify({'message': 'User updated'}), 200
            return jsonify({'error': 'User not found'}), 404
        except Error as e:
            return jsonify({'error': str(e)}), 500
        finally:
            cursor.close()
            connection.close()
    return jsonify({'error': 'Database connection failed'}), 500

@app.route('/users/<email>', methods=['DELETE'])
def delete_user(email):
    connection = get_db_connection()
    if connection:
        try:
            cursor = connection.cursor()
            query = "DELETE FROM users WHERE email = %s"
            cursor.execute(query, (email,))
            connection.commit()
            if cursor.rowcount:
                return jsonify({'message': 'User deleted'}), 200
            return jsonify({'error': 'User not found'}), 404
        except Error as e:
            return jsonify({'error': str(e)}), 500
        finally:
            cursor.close()
            connection.close()
    return jsonify({'error': 'Database connection failed'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)