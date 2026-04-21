import Phaser from "phaser";

import type {
  BuildState,
  HomeStationId,
  RoleId,
  RuntimeState,
  WorldState,
} from "../../shared/world-model.js";
import { HOME_STATIONS } from "../../shared/world-model.js";

const stationLayout: Record<
  HomeStationId,
  { x: number; y: number; width: number; height: number; label: string }
> = {
  "role-altar": { x: 144, y: 120, width: 158, height: 78, label: "职业台" },
  "skill-shelf": { x: 376, y: 118, width: 176, height: 82, label: "技能书架" },
  "equipment-forge": { x: 652, y: 122, width: 176, height: 82, label: "装备工坊" },
  "task-desk": { x: 232, y: 352, width: 186, height: 90, label: "任务桌" },
  "status-mirror": { x: 506, y: 346, width: 182, height: 86, label: "状态镜" },
  "world-portal": { x: 838, y: 302, width: 140, height: 146, label: "世界门" },
};

function roleTexture(roleId: RoleId): string {
  return roleId === "designer" ? "/role-designer.png" : `/role-${roleId}.png`;
}

class WorldScene extends Phaser.Scene {
  private mode: WorldState["scene"] = "home-base";
  private roleId: RoleId = "druid";
  private runtimeState: RuntimeState["state"] = "idle";
  private runtimeStation: HomeStationId = "role-altar";
  private activeStation: HomeStationId = "role-altar";
  private avatar?: Phaser.GameObjects.Image;
  private background?: Phaser.GameObjects.Image;
  private sceneTitle?: Phaser.GameObjects.Text;
  private runtimeLabel?: Phaser.GameObjects.Text;
  private hintLabel?: Phaser.GameObjects.Text;
  private homeDecor: Phaser.GameObjects.Rectangle[] = [];
  private stationBoxes = new Map<
    HomeStationId,
    { box: Phaser.GameObjects.Rectangle; text: Phaser.GameObjects.Text }
  >();
  private onStationSelect: (stationId: HomeStationId) => void = () => {};

  constructor() {
    super("world");
  }

  preload() {
    this.load.image("bg", "/office_bg_small.webp");
    this.load.image("role-druid", "/role-druid.png");
    this.load.image("role-assassin", "/role-assassin.png");
    this.load.image("role-mage", "/role-mage.png");
    this.load.image("role-summoner", "/role-summoner.png");
    this.load.image("role-warrior", "/role-warrior.png");
    this.load.image("role-paladin", "/role-paladin.png");
    this.load.image("role-designer", "/role-designer.png");
  }

  create() {
    this.cameras.main.setBackgroundColor("#071018");
    this.background = this.add.image(512, 288, "bg").setDisplaySize(1024, 576).setAlpha(0.92);

    this.add.rectangle(512, 36, 992, 42, 0x07111a, 0.94).setStrokeStyle(1, 0x547089, 0.5);
    this.sceneTitle = this.add
      .text(34, 20, "HOME BASE", {
        fontFamily: '"Trebuchet MS","Microsoft YaHei",sans-serif',
        fontSize: "18px",
        color: "#f4d79b",
      })
      .setResolution(2);
    this.runtimeLabel = this.add
      .text(700, 20, "基地待命中", {
        fontFamily: '"Trebuchet MS","Microsoft YaHei",sans-serif',
        fontSize: "14px",
        color: "#b6cfe3",
      })
      .setResolution(2)
      .setOrigin(1, 0);
    this.hintLabel = this.add
      .text(34, 538, "点击工位切换配置台。", {
        fontFamily: '"Trebuchet MS","Microsoft YaHei",sans-serif',
        fontSize: "13px",
        color: "#9fb8cd",
      })
      .setResolution(2);

    this.homeDecor = [
      this.add.rectangle(140, 260, 122, 120, 0x102031, 0.24).setStrokeStyle(1, 0x47647d, 0.3),
      this.add.rectangle(376, 258, 168, 130, 0x102031, 0.22).setStrokeStyle(1, 0x47647d, 0.28),
      this.add.rectangle(650, 258, 182, 132, 0x102031, 0.22).setStrokeStyle(1, 0x47647d, 0.28),
      this.add.rectangle(840, 302, 160, 188, 0x14223a, 0.18).setStrokeStyle(1, 0x6a4b8e, 0.3),
    ];

    this.avatar = this.add
      .image(148, 442, "role-druid")
      .setScale(1.95)
      .setDepth(10)
      .setOrigin(0.5, 1);

    (Object.keys(HOME_STATIONS) as HomeStationId[]).forEach((stationId) => {
      const layout = stationLayout[stationId];
      const box = this.add.rectangle(layout.x, layout.y, layout.width, layout.height, 0x14283a, 0.24);
      box.setStrokeStyle(2, 0x8ab0cf, 0.45);
      box.setInteractive({ cursor: "pointer" });
      box.on("pointerover", () => {
        this.hintLabel?.setText(`查看 ${layout.label} · ${HOME_STATIONS[stationId].description}`);
      });
      box.on("pointerout", () => {
        this.hintLabel?.setText(this.mode === "home-base" ? "点击工位切换配置台。" : "Shared World 为第二阶段骨架。");
      });
      box.on("pointerdown", () => {
        this.onStationSelect(stationId);
      });
      const text = this.add
        .text(layout.x, layout.y, layout.label, {
          fontFamily: '"Trebuchet MS","Microsoft YaHei",sans-serif',
          fontSize: "13px",
          color: "#f6e4b1",
        })
        .setResolution(2)
        .setOrigin(0.5);
      this.stationBoxes.set(stationId, { box, text });
    });

    this.renderScene();
    this.renderStations();
  }

  bindStationSelect(handler: (stationId: HomeStationId) => void) {
    this.onStationSelect = handler;
  }

  updateBuild(build: BuildState) {
    this.roleId = build.roleId;
    this.avatar?.setTexture(`role-${this.roleId}`);
    this.renderScene();
  }

  updateRuntime(runtime: RuntimeState) {
    this.runtimeState = runtime.state;
    this.runtimeStation = runtime.stationId;
    this.runtimeLabel?.setText(`${runtime.state.toUpperCase()} · ${HOME_STATIONS[runtime.stationId].label}`);
    const station = stationLayout[runtime.stationId];
    if (this.avatar && station && this.mode === "home-base") {
      this.tweens.killTweensOf(this.avatar);
      this.tweens.add({
        targets: this.avatar,
        x: station.x,
        y: station.y + 118,
        duration: runtime.state === "idle" ? 380 : 760,
        ease: "Sine.easeInOut",
      });
    }
    this.renderStations();
    this.renderScene();
  }

  updateWorld(world: WorldState) {
    this.mode = world.scene;
    this.activeStation = world.personaPanelStation;
    this.renderScene();
    this.renderStations();
  }

  private renderScene() {
    if (!this.background || !this.sceneTitle || !this.runtimeLabel || !this.hintLabel || !this.avatar) {
      return;
    }

    if (this.mode === "shared-world") {
      this.background.setTint(0x2d1938);
      this.sceneTitle.setText("SHARED WORLD SHELL");
      this.runtimeLabel.setText("大厅骨架已就绪 · 协作同步第二阶段接入");
      this.hintLabel.setText("当前只开放入口壳与回程门。\n");
      this.avatar.setPosition(838, 448);
      this.homeDecor.forEach((node, index) => {
        node.setVisible(index === 3);
      });
    } else {
      this.background.clearTint();
      this.sceneTitle.setText(`HOME BASE · ${this.roleId.toUpperCase()}`);
      this.runtimeLabel.setText(`${this.runtimeState.toUpperCase()} · ${HOME_STATIONS[this.runtimeStation].label}`);
      this.hintLabel.setText(`当前控制台：${HOME_STATIONS[this.activeStation].label}`);
      this.homeDecor.forEach((node) => node.setVisible(true));
    }
  }

  private renderStations() {
    this.stationBoxes.forEach(({ box, text }, stationId) => {
      const selected = stationId === this.activeStation;
      const running = stationId === this.runtimeStation;
      const visible = this.mode === "home-base" || stationId === "world-portal";
      box.setVisible(visible);
      text.setVisible(visible);
      if (!visible) return;

      const fill = selected ? 0x836127 : running ? 0x214665 : 0x14283a;
      const alpha = selected ? 0.55 : running ? 0.42 : 0.24;
      const stroke = selected ? 0xf0d48f : running ? 0x6fb3e1 : 0x8ab0cf;
      const strokeAlpha = selected ? 0.9 : running ? 0.75 : 0.45;
      box.setFillStyle(fill, alpha);
      box.setStrokeStyle(selected ? 3 : 2, stroke, strokeAlpha);
      text.setColor(selected ? "#fff3d3" : running ? "#d5ecff" : "#f6e4b1");
    });
  }
}

export class WorldRenderer {
  private scene?: WorldScene;
  private pendingBuild?: BuildState;
  private pendingRuntime?: RuntimeState;
  private pendingWorld?: WorldState;
  readonly game: Phaser.Game;

  constructor(mountNode: HTMLElement, onStationSelect: (stationId: HomeStationId) => void) {
    this.game = new Phaser.Game({
      type: Phaser.AUTO,
      parent: mountNode,
      width: 1024,
      height: 576,
      backgroundColor: "#071018",
      pixelArt: true,
      scale: {
        mode: Phaser.Scale.FIT,
        autoCenter: Phaser.Scale.CENTER_BOTH,
      },
      scene: [WorldScene],
    });

    this.game.events.once("ready", () => {
      this.scene = this.game.scene.getScene("world") as WorldScene;
      this.scene.bindStationSelect(onStationSelect);
      if (this.pendingBuild) this.scene.updateBuild(this.pendingBuild);
      if (this.pendingRuntime) this.scene.updateRuntime(this.pendingRuntime);
      if (this.pendingWorld) this.scene.updateWorld(this.pendingWorld);
    });
  }

  setBuild(build: BuildState) {
    this.pendingBuild = build;
    this.scene?.updateBuild(build);
  }

  setRuntime(runtime: RuntimeState) {
    this.pendingRuntime = runtime;
    this.scene?.updateRuntime(runtime);
  }

  setWorld(world: WorldState) {
    this.pendingWorld = world;
    this.scene?.updateWorld(world);
  }
}
