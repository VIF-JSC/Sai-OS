# Sai OS

**Sai** là hệ điều hành máy tính để bàn (desktop OS) chuẩn doanh nghiệp, đề cao quyền riêng tư và tối ưu cho công việc văn phòng trong các tổ chức, doanh nghiệp và cơ quan nhà nước. Được phát triển dựa trên **LMDE 7 “Gigi”** (Linux Mint Debian Edition, nền tảng **Debian 13 Trixie** độc lập, không phụ thuộc hệ sinh thái Ubuntu/Canonical), Sai mang đến một môi trường làm việc ưu tiên xử lý cục bộ (local-first), sẵn sàng sử dụng ngay sau khi cài đặt, giải phóng tổ chức khỏi sự phụ thuộc vào các nhà cung cấp độc quyền (anti-vendor lock-in) và hỗ trợ nhân sự chuyển đổi êm thuận từ Windows.

[Tiếng Việt](README.vi.md) • [English](README.md)

---

## Trọng tâm chiến lược & Giá trị cốt lõi

Sai dịch chuyển hoàn toàn khỏi mô hình hệ điều hành phụ thuộc đám mây của các hãng công nghệ lớn, tập trung vào ba trụ cột thực dụng và phục vụ trực tiếp cho tổ chức:

### 1. Quyền tự chủ dữ liệu & hạ tầng (Data Ownership & Infrastructure Autonomy)
- **Bảo mật theo thiết kế & Không Telemetry (Privacy-by-Design & Zero Telemetry)**: Toàn bộ cơ chế thu thập dữ liệu chẩn đoán, telemetry và theo dõi ngầm (bao gồm cả telemetry trên trình duyệt Firefox) đều được tắt bỏ hoặc loại bỏ mặc định. Không có dữ liệu nội bộ nào của tổ chức bị gửi ra ngoài biên giới mạng.
- **Kiến trúc ưu tiên xử lý cục bộ (Local-First Architecture)**: Mọi thao tác xử lý tài liệu văn phòng, cấu hình và tiện ích hệ thống vận hành hoàn toàn trên phần cứng tại chỗ, không bắt buộc đăng nhập tài khoản đám mây hay phụ thuộc vào dịch vụ Internet bên ngoài.
- **Tự chủ vòng đời vận hành (Sovereign Fleet Lifecycle)**: Doanh nghiệp nắm quyền kiểm soát toàn diện: từ máy chủ cập nhật nội bộ (`sai-update`), kho gói phần mềm riêng (private APT repository), cho đến chính sách sao lưu tự động khôi phục trước mỗi lần nâng cấp.

### 2. Giải phóng khỏi phụ thuộc nhà cung cấp (Anti-Vendor Lock-in & Open Standards)
- **Nền tảng Debian thượng nguồn độc lập**: Xây dựng trên LMDE 7 và Debian 13 "Trixie", giúp tổ chức thoát khỏi gánh nặng chi phí bản quyền định kỳ, sự ràng buộc hệ sinh thái độc quyền và các quy định cưỡng ép nâng cấp phần cứng (như rào cản phần cứng TPM 2.0 hoặc hạn chế đời CPU).
- **Loại bỏ kho ứng dụng đóng**: Không phụ thuộc Ubuntu và không bắt buộc sử dụng định dạng đóng gói độc quyền (hoàn toàn không dùng `snapd`), sử dụng chuẩn đóng gói Debian `.deb` và hệ thống quản lý gói `apt` tiêu chuẩn quốc tế.
- **Tuân thủ chuẩn mở**: Dựa trên kiến trúc systemd chuẩn mực, giao diện chuẩn POSIX, định dạng tài liệu mở và cấu hình dạng văn bản minh bạch.
- **Minh bạch và có thể tái tạo (Auditable & Reproducible)**: 100% mã nguồn kịch bản build, lớp phủ hệ thống (rootfs overlay) và các bước cấu hình chroot đều công khai trong kho lưu trữ này. Doanh nghiệp có thể kiểm toán từng dòng lệnh, tùy biến danh mục phần mềm và tự đóng gói bản ISO độc lập thông qua công cụ `saibuild`.

### 3. Cho tổ chức / doanh nghiệp của bạn (Enterprise-Grade & User-Centric)
- **Chuyển đổi êm thuận từ Windows**: Giao diện Cinnamon quen thuộc (thanh tác vụ phía dưới, menu khởi động Cinnamenu, các phím tắt tiêu chuẩn như `Super+E` mở File Explorer, `Ctrl+Shift+Esc` mở System Monitor, `Super+Shift+S` / `PrtSc` chụp ảnh màn hình), giảm thiểu tối đa chi phí đào tạo lại nhân sự và gián đoạn công việc.
- **Sẵn sàng cho công việc văn phòng ngay sau khi cài**: Cấu hình sẵn locale `vi_VN`, múi giờ Việt Nam, bộ font chữ hiện đại `Be Vietnam Pro` chuẩn hiển thị văn bản hành chính, bộ gõ `fcitx5` + `Lotus` (bật sẵn Telex, phím tắt chuyển đổi `` ` ``). Cài sẵn bộ công cụ văn phòng (WPS Office hoặc LibreOffice), mẫu văn bản tạo nhanh chuột phải (`New Document`), trình duyệt Firefox, ứng dụng chụp màn hình Flameshot, quản lý clipboard CopyQ.
- **Vận hành an toàn & Cơ chế Rollback tức thì**:
  - Tự động bảo trì và kiểm tra cập nhật qua `sai-update` chạy bằng systemd timer.
  - **Tự động tạo snapshot Timeshift trước mỗi lần cập nhật hệ thống**, cho phép khôi phục nguyên trạng hệ điều hành chỉ trong vài phút nếu bản cập nhật gặp sự cố tương thích.
  - Cơ chế kịch bản chuyển đổi tuần tự, chạy một lần (`/usr/share/sai/migrations/`) giúp triển khai thay đổi cấu hình đồng bộ tới toàn bộ máy trạm.
- **Thiết lập bảo mật mặc định an toàn**: Bật sẵn tường lửa `ufw` chặn toàn bộ truy cập trái phép từ bên ngoài vào máy, kích hoạt chính sách tự động khóa màn hình sau 5 phút không hoạt động.
- **Mật mã hậu lượng tử (PQC)**: TLS, Firefox và SSH mặc định dùng trao đổi khóa lai ML-KEM theo chuẩn NIST FIPS 203, người dùng ký số tài liệu bằng ML-DSA (FIPS 204) ngay trong trình quản lý tệp, `sai-pqc ca` cấp chứng thư hậu lượng tử cho máy chủ nội bộ, bản phát hành được ký bằng ML-DSA, và một bước kiểm tra hằng ngày cùng mục **Bảo mật hậu lượng tử** trong menu (`sai-pqc`) cho biết phần nào của máy đã an toàn trước máy tính lượng tử. Xem [docs/PQC.md](docs/PQC.md).
- **Tối ưu tài nguyên & Kéo dài tuổi thọ phần cứng**: Sử dụng `zram` nén RAM swap giúp máy cấu hình văn phòng chạy mượt mà; tích hợp `TLP` tối ưu hóa thời lượng pin cho laptop.

---

## Bảng tính năng tổng quan

| Nhóm chức năng | Chi tiết tính năng |
|---|---|
| **Trải nghiệm giao diện** | Giao diện Cinnamon phong cách Windows, menu Cinnamenu, taskbar quen thuộc, bộ icon Win11, con trỏ Bibata, theme Cinnamon Delight. |
| **Bản địa hóa & Phông chữ** | Sinh sẵn locale `vi_VN`, múi giờ `Asia/Ho_Chi_Minh`, phông chữ doanh nghiệp `Be Vietnam Pro`, bộ gõ `fcitx5` + `Lotus` (Telex gõ ngay, bật/tắt bằng phím `` ` ``). Giao diện mặc định Tiếng Anh, dễ dàng chuyển sang Tiếng Việt trong Cài đặt → Ngôn ngữ. |
| **Bộ ứng dụng văn phòng** | WPS Office (tùy chọn, tương thích cao với Word/Excel/PowerPoint) hoặc LibreOffice, Firefox, Flameshot, quản lý clipboard CopyQ, System Monitor, danh mục mẫu văn bản tạo nhanh (`etc/skel/Templates`). |
| **Quản trị vận hành** | Hệ thống cập nhật tập trung `sai-update`, tự động tạo snapshot Timeshift trước khi nâng cấp để rollback an toàn, hệ thống migration tuần tự. |
| **Bảo mật & Quyền riêng tư** | Bật sẵn tường lửa `ufw` chặn inbound, tự động khóa màn hình 5 phút, vô hiệu hóa telemetry, thiết lập quyền hạn người dùng an toàn. |
| **Mật mã hậu lượng tử** | Trao đổi khóa lai ML-KEM (NIST FIPS 203) cho TLS, Firefox và SSH, được kiểm tra khi build; ký số tài liệu ML-DSA (FIPS 204) từ trình quản lý tệp, CA nội bộ hậu lượng tử và chữ ký phát hành; kiểm tra tuân thủ hằng ngày (`/var/lib/sai/pqc-status.json`); công cụ `sai-pqc` và mục trong menu. |
| **Hiệu năng & Phần cứng** | `zram` nén bộ nhớ đệm giúp đa nhiệm mượt trên máy cấu hình vừa; `TLP` quản lý năng lượng nâng cao cho máy tính xách tay. |
| **Cài đặt & Triển khai** | Mục khởi động chuyên biệt **Install Sai (Install to disk)** để cài thẳng vào ổ cứng, hỗ trợ chế độ Live session dùng thử. |

---

## Hướng dẫn đóng gói bản ISO

### Yêu cầu môi trường
- Máy chủ chạy Debian, Ubuntu hoặc Linux Mint có quyền root (hoặc dùng Docker).
- Tối thiểu 15 GB dung lượng ổ cứng trống.
- Bản ISO LMDE 7 gốc (~3 GB) được tải tự động một lần và lưu vào cache.

### Lệnh đóng gói nhanh

```bash
# Bản build phát triển (nén lz4, tốc độ build nhanh để kiểm thử)
sudo ./saibuild

# Bản build phát hành (nén xz, dung lượng ISO tối ưu)
sudo ./saibuild all --release

# Xem toàn bộ các tùy chọn và trợ giúp
make help
```

### Vòng lặp phát triển nhanh (Fast Development Loop)

Dành cho nhà phát triển chỉnh sửa overlay hoặc kịch bản cấu hình:

```bash
sudo ./saibuild unpack      # Giải nén ISO gốc vào thư mục build/ (lưu cache)
sudo ./saibuild provision   # Áp dụng overlay, cài đặt gói, chạy os/provision.d/
sudo ./saibuild shell       # Truy cập môi trường chroot để kiểm thử thủ công
sudo ./saibuild quick       # Đóng gói lại ISO ngay sau khi sửa đổi rootfs overlay
bash builder/inspect-iso.sh # Kiểm tra bootloader và nhận diện thương hiệu của ISO
make test                   # Chạy kiểm thử tĩnh (không cần quyền root)
```

### Các biến môi trường tùy biến

Cấu hình các tham số qua biến môi trường (giá trị mặc định xem tại `builder/env.sh`):

| Biến | Ý nghĩa | Mặc định |
|---|---|---|
| `SAI_VERSION` | Phiên bản ghi vào tên ISO, `/etc/os-release` và menu khởi động | `0.1.0` |
| `SAI_WPS=0` | Bỏ qua WPS Office và giữ nguyên bộ LibreOffice gốc của LMDE | `1` |
| `WPS_DEB_URL` | Đường dẫn tải gói `.deb` WPS Office tùy chỉnh | URL bản dựng chính thức |
| `APT_MIRROR` | Địa chỉ Debian mirror gần nhất để tăng tốc độ tải gói | `http://deb.debian.org/debian` |

### Hỗ trợ Docker & macOS

Để biên dịch trên macOS hoặc hệ điều hành khác không phải Debian:

```bash
docker compose run builder
# Trong container:
./saibuild
```

### Kiểm thử và Tích hợp liên tục (CI)

Mọi pull request và commit đẩy lên nhánh `main` đều tự động chạy kiểm tra cú pháp (`shellcheck` và unittest Python). Khi đẩy lên `main` hoặc tạo thẻ phiên bản (`v*`), hệ thống sẽ đóng gói file ISO hoàn chỉnh và lưu trữ trong 7 ngày trên GitHub Actions; gắn thẻ phiên bản sẽ tự động tạo GitHub Release.

---

## Cấu trúc thư mục dự án

```
Sai-OS/
├── saibuild                  # CLI điều phối toàn bộ quy trình build
├── Makefile                  # Các lệnh tắt cho dev: build, test, dọn dẹp
├── builder/
│   ├── env.sh                # Tham số cấu hình build
│   ├── iso.sh                # Thao tác ISO: giải nén, tùy biến bootloader, đóng gói
│   ├── rootfs.sh             # Thao tác chroot: overlay, cài đặt gói, xác thực
│   └── inspect-iso.sh        # Kịch bản kiểm tra nhãn đĩa và bootloader
├── os/
│   ├── apt/packages.txt      # Danh sách gói phần mềm bổ sung cho môi trường văn phòng
│   ├── rootfs/               # Tệp ghi đè lên hệ thống đích (cấu hình, dịch vụ update)
│   └── provision.d/          # Các kịch bản provision chạy tuần tự trong chroot (10- đến 90-)
├── brand/
│   ├── apply.py              # Kịch bản tự động sinh asset logo, theme, màn hình khởi động
│   ├── logo/                 # File logo vector gốc
│   └── Wallpaper 4K/         # Hình nền máy tính thương hiệu
├── tests/                    # Bộ kiểm thử hồi quy tĩnh (cú pháp, gschema, cấu hình)
└── docs/
    └── REBRAND.md            # Tài liệu hướng dẫn white-label và đổi nhận diện thương hiệu
```

---

## Triển khai và Cài đặt

1. Ghi tệp `Sai-*.iso` vào ổ USB (sử dụng Ventoy, Rufus hoặc lệnh `dd`).
2. Khởi động máy trạm ở chế độ UEFI hoặc BIOS.
3. Chọn **Install Sai (Install to disk)** để vào thẳng trình cài đặt lên ổ cứng, hoặc chọn **Start Sai** để trải nghiệm trước trong phiên Live.
4. Đối với kế hoạch triển khai hàng loạt tự động, tham khảo [docs/REBRAND.md](docs/REBRAND.md), Mục 7.

---

## Quản trị cập nhật đội máy & An toàn phục hồi

Các máy trạm sau khi cài đặt được trang bị luồng bảo trì tự động qua `sai-update` (chạy hàng ngày theo systemd timer):

1. **Snapshot an toàn trước nâng cấp**: Trước khi áp dụng bất kỳ thay đổi nào, `sai-update` tự động kích hoạt tạo **snapshot Timeshift** cục bộ. Nếu có xung đột phần mềm hoặc lỗi sau cập nhật, quản trị viên hoặc người dùng có thể khôi phục hệ thống về trạng thái trước đó chỉ trong vài phút.
2. **Nâng cấp có kiểm soát**: Thực thi `apt full-upgrade` dựa trên các kho phần mềm được cấu hình. Mặc định, nguồn kho nội bộ Sai (`/etc/apt/sources.list.d/sai.sources`) được để ở trạng thái tắt cho đến khi tổ chức thiết lập mirror riêng.
3. **Kịch bản Migration tuần tự chạy một lần**: Chạy các kịch bản migration tại `/usr/share/sai/migrations/` (xem [Hướng dẫn Migrations](os/rootfs/usr/share/sai/migrations/README.md)) để cập nhật cấu hình, vá lỗi hoặc bổ sung tiện ích một cách nhất quán cho toàn bộ máy trạm đang hoạt động.

---

## Tùy biến thương hiệu cho tổ chức (White-Labeling)

Bản phát hành công khai sử dụng các giá trị định danh mẫu để đảm bảo tính độc lập và khả năng build ngay lập tức:
- **Tên miền nội bộ**: `sai.internal` (sử dụng trong trang chủ trình duyệt, tài liệu hướng dẫn nội bộ).
- **Thông tin hỗ trợ**: Thông điệp liên hệ bộ phận IT chung.
- **Kho cập nhật OTA**: Được tắt mặc định cho đến khi trỏ về máy chủ cập nhật của tổ chức.

Để triển khai Sai dưới nhận diện thương hiệu riêng của doanh nghiệp, hãy tham khảo [docs/REBRAND.md](docs/REBRAND.md). Tài liệu này liệt kê chi tiết mọi vị trí xuất hiện thương hiệu, quy chuẩn kích thước hình ảnh và danh mục kiểm tra toàn diện để đổi tên hệ điều hành.

---

## Bản quyền & Tuân thủ pháp lý

- **Mã nguồn đóng gói & Kịch bản cấu hình**: Phát hành theo giấy phép **GPL-3.0-or-later** ([LICENSE](LICENSE)).
- **Tài sản thương hiệu Sai**: Đăng ký và bảo lưu mọi quyền ([LICENSE-BRAND.md](LICENSE-BRAND.md)).
- **Hệ điều hành thượng nguồn & Các gói phần mềm**: Bản ISO hoàn chỉnh chứa các thành phần từ Debian, LMDE và hàng nghìn phần mềm mã nguồn mở theo giấy phép riêng (có thể tra cứu tại `/usr/share/doc/<package>/copyright` trên máy đã cài).
- **WPS Office (Tùy chọn)**: Phần mềm đóng gói miễn phí của Kingsoft, được tải về nguyên bản tại thời điểm build theo thỏa thuận cấp phép người dùng cuối (EULA) của Kingsoft. Xem chi tiết tại [CREDITS.md](CREDITS.md).

*Sai là một dự án độc lập, không liên kết, không được tài trợ hoặc bảo trợ bởi Linux Mint, Debian hay Canonical.*

---

## Kiểm thử & Đóng góp

Mọi đóng góp, báo lỗi và đề xuất cải tiến đều được hoan nghênh:

```bash
# Chạy kiểm thử tĩnh và kiểm tra cú pháp cục bộ
make test

# Khởi chạy thử nghiệm file ISO trong máy ảo QEMU
qemu-system-x86_64 -m 4G -enable-kvm -boot d -cdrom Sai-*.iso
```
