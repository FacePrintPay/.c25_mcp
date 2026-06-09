#!/usr/bin/env ts-node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';

const execAsync = promisify(exec);

interface AgentTask {
  agentId: string;
  task: string;
  priority: number;
  status: 'pending' | 'running' | 'complete';
}

class PlanetaryAgentsServer {
  private tasks: Map<string, AgentTask> = new Map();
  private agentQueue: AgentTask[] = [];

  async executeCommand(command: string): Promise<string> {
    try {
      const { stdout, stderr } = await execAsync(command, {
        cwd: process.env.HOME,
        env: { ...process.env, PATH: `${process.env.HOME}/.local/bin:${process.env.PATH}` }
      });
      return stdout || stderr;
    } catch (error: any) {
      return error.message;
    }
  }

  async syncStorage(): Promise<string> {
    const syncCmd = `
      mkdir -p /sdcard/C25_Agents/backup
      cp -r $HOME/.c25_mcp/* /sdcard/C25_Agents/backup/ 2>/dev/null || true
      find /sdcard -name "*agent*" -type f -exec cp {} $HOME/.c25_mcp/storage/ \\; 2>/dev/null || true
      echo "Storage synchronized"
    `;
    return await this.executeCommand(syncCmd);
  }

  async deployAgent(agentId: string, task: string): Promise<string> {
    const taskObj: AgentTask = {
      agentId,
      task,
      priority: parseInt(agentId.split('-')[1]) || 99,
      status: 'running'
    };
    
    this.tasks.set(agentId, taskObj);
    
    // Execute agent-specific deployment
    const deployScript = `$HOME/.c25_mcp/agents/${agentId}/deploy.sh`;
    if (fs.existsSync(deployScript)) {
      return await this.executeCommand(`bash ${deployScript} "${task}"`);
    }
    
    return `Agent ${agentId} task queued: ${task}`;
  }

  async getAgentStatus(): Promise<string> {
    let status = "🌌 PLANETARY AGENTS STATUS\n";
    status += "================================\n";
    
    for (const [id, task] of this.tasks) {
      status += `${id}: ${task.status} - ${task.task}\n`;
    }
    
    // Check running services
    status += "\n📊 ACTIVE SERVICES:\n";
    status += await this.executeCommand("pm2 list 2>/dev/null || ps aux | grep -E 'node|python|mongod' | head -5");
    
    return status;
  }
}

const server = new PlanetaryAgentsServer();

const mcpServer = new Server(
  {
    name: 'planetary-agents-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

mcpServer.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'deploy_agent',
        description: 'Deploy a specific planetary agent with task',
        inputSchema: {
          type: 'object',
          properties: {
            agentId: { type: 'string', description: 'Agent ID (e.g., agent-01)' },
            task: { type: 'string', description: 'Task description' }
          },
          required: ['agentId', 'task']
        }
      },
      {
        name: 'sync_storage',
        description: 'Synchronize Termux and internal storage',
        inputSchema: { type: 'object', properties: {} }
      },
      {
        name: 'agent_status',
        description: 'Get status of all agents',
        inputSchema: { type: 'object', properties: {} }
      },
      {
        name: 'execute_25step_deploy',
        description: 'Run autonomous 25-step deployment',
        inputSchema: {
          type: 'object',
          properties: {
            projectPath: { type: 'string' }
          },
          required: ['projectPath']
        }
      }
    ]
  };
});

mcpServer.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case 'deploy_agent':
      const result = await server.deployAgent(args.agentId, args.task);
      return { content: [{ type: 'text', text: result }] };
    
    case 'sync_storage':
      const syncResult = await server.syncStorage();
      return { content: [{ type: 'text', text: syncResult }] };
    
    case 'agent_status':
      const status = await server.getAgentStatus();
      return { content: [{ type: 'text', text: status }] };
    
    case 'execute_25step_deploy':
      const deployScript = `$HOME/.c25_mcp/25step_autonomous_deploy.sh`;
      if (fs.existsSync(deployScript)) {
        const output = await server.executeCommand(`bash ${deployScript} ${args.projectPath}`);
        return { content: [{ type: 'text', text: output }] };
      }
      return { content: [{ type: 'text', text: 'Deploy script not found' }] };
    
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await mcpServer.connect(transport);
  console.error('Planetary Agents MCP Server running on stdio');
}

main().catch(console.error);
