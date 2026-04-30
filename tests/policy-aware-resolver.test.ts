import { describe, expect, test, vi } from 'vitest';
import {
	PolicyAwareConflictResolver,
	PolicyAwareFirstSyncResolver,
} from '../src/sync-engine-types';
import type {
	ConflictItem,
	ConflictResolver,
	FirstSyncResolver,
	FirstSyncSummary,
} from '../src/sync-engine-types';
import type { ConflictPolicy } from '../src/settings';

function makeConflicts(): ConflictItem[] {
	return [
		{
			path: 'a.md',
			action: 'conflict',
			local: 'modified',
			remote: 'modified',
			isBinary: false,
			localSize: 0,
			remoteSize: 0,
		},
	];
}

function makeSummary(conflicts: ConflictItem[] = makeConflicts()): FirstSyncSummary {
	return {
		localOnly: [],
		remoteOnly: [],
		identical: [],
		conflicts,
	};
}

describe('PolicyAwareConflictResolver', () => {
	test('always-ask delegates to the modal', async () => {
		const modal: ConflictResolver = { resolve: vi.fn().mockResolvedValue('cancel') };
		const wrapper = new PolicyAwareConflictResolver(() => 'always-ask', modal);

		const result = await wrapper.resolve(makeConflicts());

		expect(modal.resolve).toHaveBeenCalledOnce();
		expect(result).toBe('cancel');
	});

	test('always-prefer-local resolves to keep-local without invoking the modal', async () => {
		const modal: ConflictResolver = { resolve: vi.fn() };
		const wrapper = new PolicyAwareConflictResolver(() => 'always-prefer-local', modal);

		const result = (await wrapper.resolve(makeConflicts())) as Map<string, 'keep-local' | 'keep-remote'>;

		expect(modal.resolve).not.toHaveBeenCalled();
		expect(result.get('a.md')).toBe('keep-local');
	});

	test('always-prefer-remote resolves to keep-remote without invoking the modal', async () => {
		const modal: ConflictResolver = { resolve: vi.fn() };
		const wrapper = new PolicyAwareConflictResolver(() => 'always-prefer-remote', modal);

		const result = (await wrapper.resolve(makeConflicts())) as Map<string, 'keep-local' | 'keep-remote'>;

		expect(modal.resolve).not.toHaveBeenCalled();
		expect(result.get('a.md')).toBe('keep-remote');
	});

	test('reads policy fresh on each resolve — value change after construction takes effect', async () => {
		const modal: ConflictResolver = { resolve: vi.fn().mockResolvedValue(new Map([['a.md', 'keep-remote']])) };
		let policy: ConflictPolicy = 'always-prefer-local';
		const wrapper = new PolicyAwareConflictResolver(() => policy, modal);

		const first = (await wrapper.resolve(makeConflicts())) as Map<string, 'keep-local' | 'keep-remote'>;
		expect(first.get('a.md')).toBe('keep-local');
		expect(modal.resolve).not.toHaveBeenCalled();

		policy = 'always-ask';

		await wrapper.resolve(makeConflicts());
		expect(modal.resolve).toHaveBeenCalledOnce();
	});
});

describe('PolicyAwareFirstSyncResolver', () => {
	test('always-ask delegates to the modal', async () => {
		const modal: FirstSyncResolver = { resolve: vi.fn().mockResolvedValue('cancel') };
		const wrapper = new PolicyAwareFirstSyncResolver(() => 'always-ask', modal);

		const result = await wrapper.resolve(makeSummary());

		expect(modal.resolve).toHaveBeenCalledOnce();
		expect(result).toBe('cancel');
	});

	test('always-prefer-local auto-resolves all conflicts to keep-local', async () => {
		const modal: FirstSyncResolver = { resolve: vi.fn() };
		const wrapper = new PolicyAwareFirstSyncResolver(() => 'always-prefer-local', modal);

		const result = (await wrapper.resolve(makeSummary())) as Map<string, 'keep-local' | 'keep-remote'>;

		expect(modal.resolve).not.toHaveBeenCalled();
		expect(result.get('a.md')).toBe('keep-local');
	});

	test('always-prefer-remote auto-resolves all conflicts to keep-remote', async () => {
		const modal: FirstSyncResolver = { resolve: vi.fn() };
		const wrapper = new PolicyAwareFirstSyncResolver(() => 'always-prefer-remote', modal);

		const result = (await wrapper.resolve(makeSummary())) as Map<string, 'keep-local' | 'keep-remote'>;

		expect(modal.resolve).not.toHaveBeenCalled();
		expect(result.get('a.md')).toBe('keep-remote');
	});
});
