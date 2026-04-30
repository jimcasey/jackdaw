import { diffLines } from 'diff';

export type DiffLineKind = 'context' | 'add' | 'remove';

export interface DiffLine {
	kind: DiffLineKind;
	text: string;
	localLineNumber?: number;
	remoteLineNumber?: number;
}

export function computeLineDiff(localText: string, remoteText: string): DiffLine[] {
	if (localText === '' && remoteText === '') {
		return [];
	}

	const chunks = diffLines(localText, remoteText);
	const result: DiffLine[] = [];
	let localCursor = 1;
	let remoteCursor = 1;

	for (const chunk of chunks) {
		const lines = splitChunkLines(chunk.value);
		const kind: DiffLineKind = chunk.added ? 'add' : chunk.removed ? 'remove' : 'context';

		for (const text of lines) {
			if (kind === 'context') {
				result.push({
					kind,
					text,
					localLineNumber: localCursor++,
					remoteLineNumber: remoteCursor++,
				});
			} else if (kind === 'add') {
				result.push({ kind, text, remoteLineNumber: remoteCursor++ });
			} else {
				result.push({ kind, text, localLineNumber: localCursor++ });
			}
		}
	}

	return result;
}

function splitChunkLines(value: string): string[] {
	if (value === '') return [];
	const lines = value.split('\n');
	if (value.endsWith('\n')) {
		lines.pop();
	}
	return lines;
}
