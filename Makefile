APP     = StandUpTimer
BUNDLE  = dist/$(APP).app
ICONSET = .build/AppIcon.iconset

.PHONY: build bundle run dev dev-fast clean icon

# 从 packaging/AppIcon.svg 重新生成 packaging/AppIcon.icns(改了图标 SVG 后运行一次)
# macOS 图标需要 5 个尺寸 × 普通/Retina(@2x) 两种清晰度 = 10 张 PNG,再由 iconutil 打包
icon:
	mkdir -p $(ICONSET)
	swiftc -O packaging/render.swift -o .build/render-icon
	for s in 16 32 128 256 512; do \
		.build/render-icon packaging/AppIcon.svg $(ICONSET)/icon_$${s}x$${s}.png $$s || exit 1; \
		.build/render-icon packaging/AppIcon.svg $(ICONSET)/icon_$${s}x$${s}@2x.png $$((s * 2)) || exit 1; \
	done
	iconutil -c icns $(ICONSET) -o packaging/AppIcon.icns

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp .build/release/$(APP) $(BUNDLE)/Contents/MacOS/
	cp packaging/Info.plist $(BUNDLE)/Contents/
	cp packaging/AppIcon.icns $(BUNDLE)/Contents/Resources/
	plutil -lint $(BUNDLE)/Contents/Info.plist
	codesign --force -s - $(BUNDLE)

run: bundle
	open $(BUNDLE)

dev:
	swift run

dev-fast:
	STANDUP_TIMESCALE=60 swift run

clean:
	rm -rf .build dist
