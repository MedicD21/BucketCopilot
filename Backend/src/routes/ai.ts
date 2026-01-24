/**
 * AI Copilot Routes
 * Handles AI command processing and structured action generation
 */

import express from 'express';
import Anthropic from '@anthropic-ai/sdk';

const router = express.Router();
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

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

        if (!process.env.ANTHROPIC_API_KEY) {
            return res.status(500).json({ error: 'ANTHROPIC_API_KEY is not set' });
        }

        const model = process.env.ANTHROPIC_MODEL || 'claude-3-5-sonnet-20241022';
        const systemPrompt = [
            'You are BucketPilot AI Copilot.',
            'Return ONLY valid JSON with keys: actions (array), summary (string), warnings (optional array of strings).',
            'Use double quotes for all JSON keys/strings.',
            'Do not include markdown, code fences, or extra text.',
            'Do not include trailing commas.',
            'Use ONLY these action types: create_bucket, update_bucket, delete_bucket, allocate, move, create_rule, update_rule, create_merchant_mapping.',
            'If the user asks to set a budget, use create_bucket or update_bucket with targetAmount and targetType.',
            'Use the user command and provided context to propose actions.',
        ].join(' ');

        const userPayload = JSON.stringify(
            {
                command,
                context,
            },
            null,
            2
        );

        const response = await anthropic.messages.create({
            model,
            max_tokens: 800,
            system: systemPrompt,
            messages: [
                {
                    role: 'user',
                    content: userPayload,
                },
            ],
            tools: [
                {
                    name: 'propose_actions',
                    description: 'Return structured JSON actions for the user command.',
                    input_schema: {
                        type: 'object',
                        properties: {
                            actions: {
                                type: 'array',
                                items: { type: 'object' },
                            },
                            summary: { type: 'string' },
                            warnings: {
                                type: 'array',
                                items: { type: 'string' },
                            },
                        },
                        required: ['actions', 'summary'],
                    },
                },
            ],
            tool_choice: {
                type: 'tool',
                name: 'propose_actions',
            },
        });

        const toolBlock = response.content.find((block) => block.type === 'tool_use');
        if (!toolBlock || toolBlock.type !== 'tool_use') {
            throw new Error('AI response did not include tool output');
        }
        const parsed = coerceToolInput(toolBlock.input);
        const summary = resolveSummary(parsed);
        const rawActions = resolveActions(parsed);
        const { normalized, warnings } = normalizeActions(rawActions);
        const parsedWarnings = resolveWarnings(parsed);

        res.json({
            actions: normalized,
            summary,
            warnings: warnings.length > 0 ? [...(parsedWarnings ?? []), ...warnings] : parsedWarnings,
        } satisfies AICommandResponse);
    } catch (error) {
        console.error('Error processing AI command:', error);
        res.status(500).json({
            error: 'Failed to process AI command',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});

export default router;

function coerceToolInput(input: unknown): Record<string, any> {
    if (typeof input === 'string') {
        try {
            return JSON.parse(input) as Record<string, any>;
        } catch {
            return { summary: input };
        }
    }
    if (input && typeof input === 'object') {
        return input as Record<string, any>;
    }
    return {};
}

function resolveSummary(parsed: Record<string, any>): string {
    if (typeof parsed.summary === 'string' && parsed.summary.trim().length > 0) {
        return parsed.summary;
    }
    if (typeof parsed.message === 'string' && parsed.message.trim().length > 0) {
        return parsed.message;
    }
    if (typeof parsed.text === 'string' && parsed.text.trim().length > 0) {
        return parsed.text;
    }
    return 'AI response received';
}

function resolveWarnings(parsed: Record<string, any>): string[] | undefined {
    if (Array.isArray(parsed.warnings)) {
        return parsed.warnings.filter((warning) => typeof warning === 'string');
    }
    return undefined;
}

function resolveActions(parsed: Record<string, any>): AIAction[] {
    if (Array.isArray(parsed.actions)) {
        return parsed.actions;
    }
    if (Array.isArray(parsed.proposed_actions)) {
        return parsed.proposed_actions;
    }
    if (parsed.action && typeof parsed.action === 'object') {
        return [parsed.action];
    }
    if (parsed.actions && typeof parsed.actions === 'object') {
        return [parsed.actions];
    }
    return [];
}

const ALLOWED_ACTIONS = new Set([
    'create_bucket',
    'update_bucket',
    'delete_bucket',
    'allocate',
    'move',
    'create_rule',
    'update_rule',
    'create_merchant_mapping',
]);

const TYPE_ALIASES: Record<string, string> = {
    createbudget: 'create_bucket',
    create_budget: 'create_bucket',
    updatebudget: 'update_bucket',
    update_budget: 'update_bucket',
    setbudget: 'update_bucket',
    set_budget: 'update_bucket',
    deletebudget: 'delete_bucket',
    delete_budget: 'delete_bucket',
};

function normalizeActions(actions: AIAction[]): { normalized: AIAction[]; warnings: string[] } {
    const normalized: AIAction[] = [];
    const warnings: string[] = [];

    for (const action of actions) {
        const obj: Record<string, any> =
            typeof action === 'string' ? { type: action } : (action as Record<string, any>);

        if (!obj || typeof obj !== 'object' || Array.isArray(obj)) {
            warnings.push('Skipped invalid action format');
            continue;
        }

        const rawType =
            obj.type ?? obj.action ?? obj.actionType ?? obj.action_type;

        if (typeof rawType !== 'string' || rawType.trim().length === 0) {
            warnings.push('Skipped action without type');
            continue;
        }

        const normalizedType = normalizeType(rawType);
        if (!normalizedType) {
            warnings.push(`Skipped unsupported action type: ${rawType}`);
            continue;
        }

        obj.type = normalizedType;
        normalized.push(obj as AIAction);
    }

    return { normalized, warnings };
}

function normalizeType(type: string): string | null {
    const lower = type.toLowerCase();
    const snake = lower.includes('_')
        ? lower
        : lower.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();

    const aliased = TYPE_ALIASES[snake] ?? snake;
    return ALLOWED_ACTIONS.has(aliased) ? aliased : null;
}
