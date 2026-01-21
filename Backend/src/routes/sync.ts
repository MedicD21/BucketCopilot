/**
 * Event Sync Routes
 * Handles bi-directional event sync using event sourcing
 */

import express from 'express';
import { supabase, Tables, handleSupabaseError } from '../db/supabase';

const router = express.Router();

/**
 * POST /sync/pushEvents
 * Pushes local events from iOS app to server
 */
router.post('/pushEvents', async (req, res) => {
    try {
        const { events } = req.body;
        const userId = 'user-123'; // TODO: From auth middleware
        
        if (!Array.isArray(events)) {
            return res.status(400).json({ error: 'events must be an array' });
        }
        
        if (events.length === 0) {
            return res.json({ success: true, events: [] });
        }
        
        // Prepare events for insertion
        const eventsToInsert = events.map((event: any) => ({
            user_id: userId,
            event_type: event.type || event.eventType,
            timestamp: event.timestamp || new Date().toISOString(),
            payload: event.payload || event,
            device_id: event.deviceId || null,
        }));
        
        // Insert events into Supabase
        const { data, error } = await supabase
            .from(Tables.EVENTS)
            .insert(eventsToInsert)
            .select();
        
        if (error) {
            throw error;
        }
        
        res.json({
            success: true,
            events: data || [],
        });
    } catch (error) {
        console.error('Error pushing events:', error);
        res.status(500).json({
            error: 'Failed to push events',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

/**
 * GET /sync/pullEvents
 * Pulls events from server since last sync cursor
 */
router.get('/pullEvents', async (req, res) => {
    try {
        const { sinceTimestamp, sinceSequence } = req.query;
        const userId = 'user-123'; // TODO: From auth middleware
        
        // Build query for events after cursor
        if (sinceTimestamp) {
            const timestamp = new Date(sinceTimestamp as string).toISOString();
            const sequence = sinceSequence ? parseInt(sinceSequence as string) : 0;
            
            // Get events: timestamp > cursorTimestamp OR (timestamp = cursorTimestamp AND sequence > cursorSequence)
            // Supabase PostgREST filter syntax
            const { data, error } = await supabase
                .from(Tables.EVENTS)
                .select('*')
                .eq('user_id', userId)
                .or(`timestamp.gt.${timestamp},and(timestamp.eq.${timestamp},sequence.gt.${sequence})`)
                .order('timestamp', { ascending: true })
                .order('sequence', { ascending: true })
                .limit(500);
                
            if (error) {
                throw error;
            }
            
            const lastEvent = data && data.length > 0 ? data[data.length - 1] : null;
            
            return res.json({
                events: data || [],
                hasMore: data ? data.length === 500 : false,
                nextCursor: lastEvent
                    ? {
                          timestamp: lastEvent.timestamp,
                          sequence: lastEvent.sequence,
                      }
                    : {
                          timestamp: new Date().toISOString(),
                          sequence: 0,
                      },
            });
        }
        
        // No cursor: get all events
        const { data, error } = await supabase
            .from(Tables.EVENTS)
            .select('*')
            .eq('user_id', userId)
            .order('timestamp', { ascending: true })
            .order('sequence', { ascending: true })
            .limit(500);
        
        if (error) {
            throw error;
        }
        
        // Get the last event's cursor for next request
        const lastEvent = data && data.length > 0 ? data[data.length - 1] : null;
        
        res.json({
            events: data || [],
            hasMore: data ? data.length === 500 : false,
            nextCursor: lastEvent
                ? {
                      timestamp: lastEvent.timestamp,
                      sequence: lastEvent.sequence,
                  }
                : {
                      timestamp: new Date().toISOString(),
                      sequence: 0,
                  },
        });
    } catch (error) {
        console.error('Error pulling events:', error);
        res.status(500).json({
            error: 'Failed to pull events',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

export default router;
