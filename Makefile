.PHONY: help up seed down reset logs ps pull

help:
	@echo "make up      Dựng WAF + app echo, seed cấu hình BTC (lần đầu ~1-2 phút)"
	@echo "make seed    Seed lại cấu hình BTC (không đè cấu hình bạn sửa)"
	@echo "make pull    Tải bản image mới nhất"
	@echo "make down    Dừng (giữ cấu hình và log)"
	@echo "make reset   Xoá sạch cấu hình WAF và log, về như mới tải"
	@echo "make logs    Xem log realtime"

up:
	@test -f .env || cp .env.example .env
	docker compose up -d
	@$(MAKE) --no-print-directory seed

# Chờ BunkerWeb tạo bảng và tài khoản gốc ở lần khởi động đầu, ghi seed (nằm trong
# image), rồi tạo lại container để nginx sinh cấu hình từ seed.
# Seed của BTC tạo thêm tài khoản đội khi team_user khác tài khoản admin; bản tập chỉ
# có một tài khoản nên truyền chính ADMIN_USERNAME để seed bỏ qua phần đó.
seed:
	@ok=; for i in $$(seq 1 60); do docker compose exec -T postgres psql -U bunkerweb -d bunkerweb -Atc "select 1 from bw_ui_users where admin limit 1" 2>/dev/null | grep -q 1 && ok=1 && break; sleep 2; done; [ -n "$$ok" ] || { echo "BunkerWeb chưa sẵn sàng sau 120s, xem: make logs"; exit 1; }
	@U=$$(grep '^ADMIN_USERNAME=' .env | cut -d= -f2- | sed -e "s/^'//" -e "s/'$$//"); \
	[ -n "$$U" ] || { echo "Thiếu ADMIN_USERNAME trong .env"; exit 1; }; \
	R=$$(docker compose exec -T fuap_bunkerweb cat /usr/share/fhacker/rules/mau-rule-phong-thu.conf) || exit 1; \
	docker compose exec -T fuap_bunkerweb cat /usr/share/fhacker/bunkerweb-seed.sql | docker compose exec -T postgres psql -q -v ON_ERROR_STOP=1 -U bunkerweb -d bunkerweb -v team_user="$$U" -v team_pw=unused -v team_rule="$$R"
	docker compose up -d --no-deps --force-recreate fuap_bunkerweb
	@B=$$(grep "^BW_PORT=" .env | cut -d= -f2); U=$$(grep "^BW_UI_PORT=" .env | cut -d= -f2); echo "✅ app qua WAF: http://localhost:$${B:-8000}/  |  WAF UI: http://localhost:$${U:-8005}/"

pull:
	docker compose pull

down:
	docker compose down

reset:
	docker compose down -v

logs:
	docker compose logs -f fuap_bunkerweb

ps:
	docker compose ps
