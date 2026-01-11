const express = require('express');
const cors = require('cors');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage (in production, use a database)
let appointments = [];
let nextId = 1;

// Debug logging helper
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${level}] ${message}`;
  console.log(logMessage);
  if (data) {
    console.log('Data:', JSON.stringify(data, null, 2));
  }
}

// WebSocket server
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Broadcast to all connected clients
function broadcast(data) {
  const message = JSON.stringify(data);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

wss.on('connection', (ws) => {
  log('INFO', 'WebSocket client connected');

  ws.on('close', () => {
    log('INFO', 'WebSocket client disconnected');
  });

  ws.on('error', (error) => {
    log('ERROR', 'WebSocket error', { error: error.message });
  });
});

// Root route - API information
app.get('/', (req, res) => {
  res.json({
    name: 'CliniqueHarmony API Server',
    version: '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: 'GET /health',
      appointments: {
        list: 'GET /appointments',
        get: 'GET /appointments/:id',
        create: 'POST /appointments',
        update: 'PUT /appointments/:id',
        delete: 'DELETE /appointments/:id'
      },
      websocket: 'ws://localhost:3000'
    }
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// GET /appointments - Read all appointments
app.get('/appointments', (req, res) => {
  log('DEBUG', 'GET /appointments - Reading all appointments');
  log('DEBUG', `Found ${appointments.length} appointments`);
  res.json(appointments);
});

// GET /appointments/:id - Read single appointment
app.get('/appointments/:id', (req, res) => {
  const { id } = req.params;
  log('DEBUG', `GET /appointments/${id} - Reading appointment`);

  const appointment = appointments.find(apt => apt.id === id);

  if (!appointment) {
    log('WARN', `Appointment ${id} not found`);
    return res.status(404).json({ error: 'Appointment not found' });
  }

  log('DEBUG', 'Appointment found', appointment);
  res.json(appointment);
});

// POST /appointments - Create new appointment
app.post('/appointments', (req, res) => {
  log('DEBUG', 'POST /appointments - Creating new appointment', req.body);

  const { userID, practitionerID, service, date, status } = req.body;

  // Validation
  if (!userID || !practitionerID || !service || !date) {
    log('WARN', 'Validation failed: missing required fields');
    return res.status(400).json({
      error: 'Missing required fields: userID, practitionerID, service, and date are required'
    });
  }

  // Server manages the ID
  const id = `apt-${nextId++}`;
  const appointment = {
    id,
    userID,
    practitionerID,
    service,
    date: new Date(date).toISOString(),
    status: status || 'Booked'
  };

  appointments.push(appointment);
  log('INFO', `Created appointment with ID: ${id}`, appointment);

  // Broadcast to WebSocket clients
  broadcast({ type: 'appointment_created', appointment });

  res.status(201).json(appointment);
});

// PUT /appointments/:id - Update existing appointment
app.put('/appointments/:id', (req, res) => {
  const { id } = req.params;
  log('DEBUG', `PUT /appointments/${id} - Updating appointment`, req.body);

  const appointmentIndex = appointments.findIndex(apt => apt.id === id);

  if (appointmentIndex === -1) {
    log('WARN', `Appointment ${id} not found for update`);
    return res.status(404).json({ error: 'Appointment not found' });
  }

  // Reuse the existing element, update properties (ID remains the same)
  const existingAppointment = appointments[appointmentIndex];
  const { userID, practitionerID, service, date, status } = req.body;

  // Update only provided fields
  if (userID !== undefined) existingAppointment.userID = userID;
  if (practitionerID !== undefined) existingAppointment.practitionerID = practitionerID;
  if (service !== undefined) existingAppointment.service = service;
  if (date !== undefined) existingAppointment.date = new Date(date).toISOString();
  if (status !== undefined) existingAppointment.status = status;

  // ID remains the same - we're reusing the element
  appointments[appointmentIndex] = existingAppointment;

  log('INFO', `Updated appointment with ID: ${id}`, existingAppointment);

  // Broadcast to WebSocket clients
  broadcast({ type: 'appointment_updated', appointment: existingAppointment });

  res.json(existingAppointment);
});

// DELETE /appointments/:id - Delete appointment
app.delete('/appointments/:id', (req, res) => {
  const { id } = req.params;
  log('DEBUG', `DELETE /appointments/${id} - Deleting appointment`);

  const appointmentIndex = appointments.findIndex(apt => apt.id === id);

  if (appointmentIndex === -1) {
    log('WARN', `Appointment ${id} not found for deletion`);
    return res.status(404).json({ error: 'Appointment not found' });
  }

  // Remove the appointment (only ID is needed, element is properly identified)
  const deletedAppointment = appointments.splice(appointmentIndex, 1)[0];

  log('INFO', `Deleted appointment with ID: ${id}`, deletedAppointment);

  // Broadcast to WebSocket clients
  broadcast({ type: 'appointment_deleted', appointmentId: id });

  res.status(204).send();
});

// Error handling middleware
app.use((err, req, res, next) => {
  log('ERROR', 'Server error', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
server.listen(PORT, () => {
  log('INFO', `Server running on http://localhost:${PORT}`);
  log('INFO', 'WebSocket server ready');
});
