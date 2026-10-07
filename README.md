# Nếp

Bảng công việc cá nhân dạng static web app. Không cần Node.js để chạy hoặc deploy. Chưa cấu hình Supabase thì dữ liệu chỉ nằm trong trình duyệt hiện tại; sau khi cấu hình, mỗi tài khoản có danh sách riêng và các thiết bị đăng nhập cùng tài khoản sẽ đồng bộ qua Supabase.

Người dùng tự tạo, đổi tên, sắp thứ tự, lưu trữ hoặc xóa nhóm; các nhóm gợi ý ban đầu có thể bỏ qua. Công việc hỗ trợ trạng thái cần làm/đang làm/hoàn thành, lặp hằng ngày/ngày trong tuần/hằng tuần theo thứ đã chọn/hằng tháng tới ngày kết thúc, phút dự kiến và phút thực tế tuỳ chọn. Mỗi task có thể là **Đã chốt** hoặc **Dự kiến**, cùng quy tắc **Cho phép trùng**, **Cảnh báo nếu trùng** hoặc **Không được trùng giờ**. Cảnh báo cho biết task va chạm, độ chắc chắn và ưu tiên; task đã chốt với quy tắc cứng sẽ bị chặn, task dự kiến không khóa lịch cứng.

Lặp **ngày trong tuần tự chọn** cho phép chọn nhiều thứ (ví dụ Thứ Hai và Thứ Tư) và sinh các lần hẹn tới ngày kết thúc. Khi sửa một series, các lần tương lai chưa hoàn thành được tạo lại; các lần đã hoàn thành được giữ nguyên. View **Deadline** có toàn bộ hạn chưa hoàn thành với đếm ngược từng việc; danh sách ở dashboard cũng hiển thị nhiều deadline gần nhất.

Tên người sở hữu và tên bảng có thể sửa trong **Hồ sơ**; khi đăng nhập cloud, thông tin được lưu trong metadata tài khoản. Mục **Lịch** cho xem tháng, chọn ngày để lọc công việc và deadline. Lịch lặp cần ngày kết thúc và tạo trước từng lần hẹn trong khoảng đó.

Nút **Xuất lịch .ics** xuất các việc chưa hoàn thành trong tháng đang xem. Sự kiện có giờ chứa nhắc trước 15 phút. Nhập file `.ics` vào Google Calendar, Apple Calendar hoặc Outlook để nhận nhắc theo ứng dụng lịch của thiết bị, kể cả khi Nếp đóng. Đây là bản xuất một chiều; nếu đổi task cần xuất/nhập lại. Nút **Bật nhắc trong trang** chỉ nhắc khi Nếp đang mở.

Các task có giờ bắt đầu hoặc deadline có đồng hồ đếm ngược; dashboard làm nổi bật mốc sắp tới gần nhất. Nếu cho phép thông báo trình duyệt, Nếp gửi một thông báo trước 15 phút cho giờ bắt đầu và deadline. Cảnh báo trong Nếp chỉ chạy khi trang đang mở; khi đóng trang, hãy nhập `.ics` để ứng dụng lịch của điện thoại/desktop đảm nhiệm nhắc.

## Chạy thử trên máy

Mở `index.html` trong trình duyệt để dùng chế độ lưu trên thiết bị. Nếu muốn thử đăng nhập/Supabase ở local, chạy static server trong thư mục dự án, ví dụ:

```powershell
py -m http.server 8000
```

Mở `http://localhost:8000`. `file://` không phù hợp để kiểm tra xác thực cloud và callback email.

## Tạo backend Supabase

1. Tạo một project tại Supabase và mở **SQL Editor**.
2. Chạy toàn bộ bản mới nhất của `supabase/schema.sql` (kể cả project đã chạy bản trước để thêm ngày lặp tùy chọn, ID series, độ chắc chắn và quy tắc xung đột). Bảng bật Row Level Security; các policy chỉ cho phép tài khoản đọc/sửa/xóa dòng có `user_id` của chính mình.
3. Trong **Project Settings → API**, lấy Project URL và publishable key (hoặc legacy `anon` key). Không dùng `service_role` key ở trình duyệt.
4. Điền hai giá trị vào `config.js`:

```js
window.APP_CONFIG = {
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",
  supabaseAnonKey: "YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY"
};
```

Publishable/anon key được gửi tới trình duyệt; an toàn phụ thuộc vào RLS. `service_role` key sẽ bỏ qua RLS và không được đưa vào frontend, Git hay Vercel.

5. Trong **Authentication → URL Configuration**, đặt Site URL là URL deploy và thêm các redirect URL cần dùng (URL Vercel và `http://localhost:8000/**`). Bật Email provider. Nếu bật xác nhận email, người dùng cần xác nhận email trước khi đăng nhập.

## Deploy static site lên Vercel

1. Đưa thư mục dự án lên một repository Git riêng tư của bạn. `config.js` chỉ chứa URL và public key; tuyệt đối không thêm `service_role` key.
2. Trong Vercel, chọn **Add New → Project**, import repository.
3. Chọn framework **Other**; để trống Build Command và đặt Output Directory là `.` (thư mục gốc chứa `index.html`). Deploy.
4. Thêm URL Vercel vào Site URL/redirect allowlist của Supabase như bước trên.
5. Mở URL Vercel trên laptop, điện thoại, iPad; tạo tài khoản một lần và đăng nhập cùng tài khoản trên từng thiết bị.

Hosting chỉ phục vụ giao diện. Dữ liệu đồng bộ nằm ở Supabase. Tài khoản khác không đọc được task của bạn nếu RLS trong schema được giữ nguyên.

## Chuyển dữ liệu cũ và sao lưu

Khi tài khoản cloud mới đăng nhập trên thiết bị đang có dữ liệu cũ, app sẽ hiện nút **Chuyển các việc trên máy này lên cloud**. Hãy chỉ bấm nếu muốn nhập các task local đó vào tài khoản đang đăng nhập. App không tự chuyển dữ liệu sang một tài khoản khác.

**Tải bản sao** xuất JSON. **Nhập bản sao** gộp task theo ID (và nhóm nếu có) vào tài khoản hiện tại hoặc thiết bị local. Nên tải bản sao định kỳ.

## Giới hạn hiện tại

- Đồng bộ cloud cần mạng; khi mất mạng, thay đổi mới chưa có hàng đợi đồng bộ ngoại tuyến.
- Realtime cập nhật thay đổi từ thiết bị khác. Nếu cùng sửa một task cùng lúc, lần ghi sau cùng sẽ thắng.
- Nếp chưa đồng bộ hai chiều với Google/Apple Calendar; file `.ics` là bản chụp lịch tại thời điểm xuất.
- Nhắc trong trình duyệt cần cấp quyền và để trang mở. Thông báo nền sau khi nhập `.ics` do ứng dụng lịch của thiết bị quản lý.
- Email, task và ghi chú được lưu trong project Supabase bạn tạo; tránh lưu thông tin nhạy cảm không cần thiết.