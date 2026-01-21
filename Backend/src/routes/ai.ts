/**
 * AI Copilot Routes
 * Handles AI command processing and structured action generation
 */

import express from 'express';

const router = express.Router();

interface AICommandRequest {
    command: string;
    context: {
        unassignedBalance: number;
        buckets: Array<{
            id: string;
            name: string;
            available: number;
        }>;
        recentTransactions: Array<{
            id: string;
            merchantName: string;
            amount: number;
            date: string;
        }>;
    };
}

interface AIAction {
    type: string;
    id?: string;
    [key: string]: any;
}

interface AICommandResponse {
    actions: AIAction[];
    summary: string;
    warnings?: string[];
}

/**
 * POST /ai/command
 * Processes user command and returns structured JSON actions
 */
router.post('/command', async (req, res) => {
    try {
        const { command, context }: AICommandRequest = req.body;
        
        if (!command) {
            return res.status(400).json({ error: 'command is required' });
        }
        
        // TODO: Implement AI service integration
        // - OpenAI or Anthropic API call
        // - Function calling / structured outputs
        // - Guardrails validation
        
        // Placeholder response
        const response: AICommandResponse = {
            actions: [],
            summary: 'AI copilot not yet implemented',
            warnings: ['This is a placeholder response'],
        };
        
        // Example response structure:
        // response = {
        //     actions: [
        //         {
        //             type: 'allocate',
        //             bucketId: 'bucket-123',
        //             amount: 50.00,
        //         },
        //     ],
        //     summary: 'Allocate $50.00 to Groceries',
        // };
        
        res.json(response);
    } catch (error) {
        console.error('Error processing AI command:', error);
        res.status(500).json({
            error: 'Failed to process AI command',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

export default router;
