import { Notice, Platform, Plugin } from 'obsidian';
import { Settings, DEFAULT_SETTINGS } from './settings';
import { JackdawSettingsTab } from './ui/settings-tab';
import { RibbonIcon } from './ui/ribbon';
import { StatusBar } from './ui/status-bar';
import { GitHubClient } from './github-client';

export default class JackdawPlugin extends Plugin {
	settings!: Settings;
	client!: GitHubClient;

	async onload(): Promise<void> {
		if (Platform.isAndroidApp) {
			new Notice('Jackdaw: This plugin is not supported on Android. iOS and desktop only.');
			return;
		}

		await this.loadSettings();

		this.client = new GitHubClient(
			() => this.settings.pat,
			() => this.settings.owner,
			() => this.settings.repo,
			this.manifest.version,
		);

		this.addSettingTab(new JackdawSettingsTab(this.app, this, this.client));

		let statusBar: StatusBar | undefined;
		if (!Platform.isMobileApp) {
			statusBar = new StatusBar(this.addStatusBarItem());
		}

		const syncAction = async (): Promise<void> => {
			ribbon.setSyncing();
			statusBar?.setSyncing();
			try {
				// TODO: wire sync engine
				new Notice('Jackdaw: Sync coming soon');
			} finally {
				ribbon.setIdle();
				statusBar?.setIdle(null);
			}
		};

		const ribbon = new RibbonIcon(this, syncAction);

		this.addCommand({
			id: 'sync-vault',
			name: 'Sync with GitHub',
			callback: syncAction,
		});
	}

	onunload(): void {}

	async loadSettings(): Promise<void> {
		this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
	}

	async saveSettings(): Promise<void> {
		await this.saveData(this.settings);
	}
}
