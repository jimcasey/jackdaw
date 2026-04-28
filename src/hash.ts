function toHex(buffer: ArrayBuffer): string {
	return Array.from(new Uint8Array(buffer))
		.map(b => b.toString(16).padStart(2, '0'))
		.join('');
}

export async function sha256(bytes: ArrayBuffer): Promise<string> {
	return toHex(await crypto.subtle.digest('SHA-256', bytes));
}

export async function gitBlobSha1(bytes: ArrayBuffer): Promise<string> {
	const header = new TextEncoder().encode(`blob ${bytes.byteLength}\0`);
	const combined = new Uint8Array(header.byteLength + bytes.byteLength);
	combined.set(header, 0);
	combined.set(new Uint8Array(bytes), header.byteLength);
	return toHex(await crypto.subtle.digest('SHA-1', combined));
}
