# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
> Cách trả lời: điền câu trả lời trực tiếp bên dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Chu Minh Quân  Mã học viên: 2A202602709

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy lên Cloud (như Render hoặc Railway), nếu lập trình viên quên cấu hình biến môi trường `AGENT_API_KEY` trong dashboard, nếu có giá trị mặc định như `"changeme"` thì app vẫn khởi động bình thường. Khi đó kẻ tấn công hoặc bot quét Internet có thể dò ra khóa mặc định và gọi API miễn phí làm cạn kiệt ngân sách hoặc đánh cắp tài nguyên mà ta không hay biết. Ngược lại, việc không có giá trị mặc định khiến app "chết sớm" (fail fast) ngay lúc khởi động với lỗi `ValidationError` rõ ràng trong build/startup log, buộc ta phải bổ sung secret ngay lập tức trước khi ứng dụng tiếp nhận traffic công khai.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T16:19:20.123456+00:00", "user_id": "sv-test", "tokens_in": 145, "tokens_out": 45, "cost_usd": 0.00004875}
```

Hai việc làm được với log có cấu trúc:
1. **Truy vấn và thống kê tự động:** Dùng các công cụ thu thập log tập trung (Datadog, Grafana Loki, CloudWatch, ELK) để lọc chính xác log theo trường như `user_id == "sv-test"` hoặc tính tổng chi phí `cost_usd` phát sinh trong từng khung giờ mà không cần dùng regex phân tích chuỗi text thô.
2. **Thiết lập cảnh báo (Alerting) theo ngưỡng chỉ số:** Có thể cấu hình hệ thống giám sát tự động kích hoạt cảnh báo khi `cost_usd` của một request vượt ngưỡng bất thường hoặc khi số lượng request của một `user_id` tăng đột biến, giúp phát hiện hành vi lạm dụng kịp thời.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1.02 GB |
| Multi-stage | ~238 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~780 MB) gồm toàn bộ môi trường biên dịch và công cụ phát triển không cần thiết cho runtime: trình biên dịch C/C++ (`build-essential`, `gcc`), các thư viện header (`python3-dev`), package cache của `apt` và `pip`, cùng các tiện ích hệ điều hành của Debian đầy đủ. Trong khi đó, bản multi-stage chỉ sử dụng base image `python:3.11-slim` tối giản cho stage runtime và chỉ copy các file thư viện Python đã cài đặt từ stage builder sang `/usr/local`.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Khi sửa một ký tự trong `app/main.py`: Docker tái sử dụng lại (cached) toàn bộ các layer phía trước bao gồm base image, `COPY requirements.txt .` và `RUN pip install ...`. Chỉ layer `COPY . .` và các layer kế sau nó mới phải chạy lại, giúp thời gian build chỉ mất chưa đến 1-2 giây.
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Bất cứ khi nào có thay đổi trong mã nguồn, layer `COPY . .` bị thay đổi làm vô hiệu hóa (invalidate) toàn bộ layer cache từ thời điểm đó trở đi. Khi đó Docker bắt buộc phải thực hiện lại `pip install` từ đầu, tải và cài lại toàn bộ thư viện mỗi lần sửa code, gây lãng phí băng thông và làm chậm quá trình CI/CD.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện:
  1. Ứng dụng Python có lỗ hổng bảo mật (ví dụ lỗi RCE do thư viện bên thứ ba hoặc deserialize không an toàn).
  2. Kẻ tấn công khai thác lỗ hổng để thực thi lệnh shell trong container. Vì container đang chạy với user root mặc định (UID 0), kẻ tấn công nắm toàn quyền quản trị cao nhất bên trong container.
  3. Kẻ tấn công tìm cách thoát khỏi container (container breakout) thông qua việc khai thác lỗ hổng kernel Linux, mount nhầm file nhạy cảm của host (như `/var/run/docker.sock`) hoặc privileged capability. Do tiến trình trong container ánh xạ với UID 0 trên host, kẻ tấn công chiếm toàn quyền root trên máy chủ host.
- Lệnh `USER appuser` (UID 10001) cắt đứt chuỗi tấn công ngay từ bước 2: khi chiếm được quyền thực thi trong container, kẻ tấn công chỉ có quyền hạn của một người dùng thông thường, không thể cài đặt thêm công cụ, không thể sửa đổi file hệ thống container và bị chặn hoàn toàn khả năng tương tác với các tài nguyên đặc quyền của host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Người dùng có thể gửi tối đa **20 request** trong 2 giây liên tiếp.
Cách đạt được: Người dùng gửi 10 request ở giây thứ 59 của phút trước (ví dụ 10:00:59). Đến đúng 10:01:00, đồng hồ hệ thống chuyển sang phút mới và bộ đếm reset về 0, người dùng gửi tiếp ngay 10 request nữa tại giây 10:01:00. Như vậy, trong khoảng thời gian chỉ vỏn vẹn 2 giây (10:00:59 - 10:01:00), hệ thống phải tiếp nhận tới 20 request (gấp đôi hạn mức quy định), gây nguy cơ quá tải. Cửa sổ trượt (sliding window) khắc phục triệt để vấn đề này vì luôn tính tổng số request trong 60 giây gần nhất tính từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Khác nhau:
  - **Rate limiter** bảo vệ **hạ tầng dịch vụ** khỏi bị quá tải bằng cách giới hạn **tần suất/số lượng request** trong một đơn vị thời gian ngắn (ví dụ: 10 request/phút).
  - **Cost guard** bảo vệ **ngân sách tài chính** bằng cách giới hạn **tổng chi phí tích lũy** theo token LLM trong một chu kỳ dài (ví dụ: tối đa $10.0/tháng).
- Tình huống Rate limit cho qua nhưng Cost guard chặn: Người dùng chỉ gửi 1 request trong phút đó (hoàn toàn hợp lệ theo rate limit 10 req/phút), nhưng request này kèm theo prompt tài liệu rất lớn hoặc người dùng đã tiêu hết hạn mức $10.0 của tháng $\rightarrow$ Cost guard sẽ chặn và trả về HTTP 402 Payment Required.
- Tình huống Cost guard cho qua nhưng Rate limit chặn: Người dùng mới bắt đầu chu kỳ và chỉ mới tiêu hết $0.01 (ngân sách còn rất nhiều), nhưng lại gửi 15 request dồn dập chỉ trong 3 giây $\rightarrow$ Cost guard cho phép, nhưng Rate limit sẽ chặn từ request thứ 11 và trả về HTTP 429 Too Many Requests.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:
1. Redis gặp sự cố mạng hoặc khởi động lại, mất kết nối trong 30 giây.
2. Probe liveness kiểm tra `/health` trên cả 3 container; do `/health` phụ thuộc Redis nên cả 3 container đồng loạt báo unhealthy (trả 503 hoặc timeout).
3. Orchestrator (Docker/Kubernetes/Cloud platform) hiểu rằng cả 3 container đã bị hỏng tiến trình (dead process) nên tiến hành restart cả 3 container cùng lúc.
4. Trong lúc 3 container đang restart, toàn bộ cụm rơi vào tình trạng downtime hoàn toàn, người dùng nhận lỗi 502 Bad Gateway.
5. Khi Redis phục hồi sau 30 giây, các container vẫn đang trong quá trình khởi động lại hoặc restart-loop, biến một lỗi gián đoạn tạm thời của dependency thành sự cố sập toàn diện hệ thống. (Khi tách riêng, `/health` vẫn trả 200 để giữ container sống, chỉ `/ready` trả 503 để load balancer tạm thời không chuyển traffic tới).

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Nếu lưu trong dict Python (trong bộ nhớ RAM của từng tiến trình):
Khi gửi nhiều request liên tiếp, Load balancer sẽ phân phối request xoay vòng qua 3 instance A, B, C khác nhau. Vì mỗi instance có bộ nhớ RAM độc lập nên `history_length` sẽ thay đổi bất thường và không đồng nhất: lúc thì tăng lên ở một instance, lúc lại quay về 0 hoặc một con số nhỏ hơn ở instance khác. Người dùng sẽ thấy câu trả lời của agent bị "mất trí nhớ" ngẫu nhiên giữa các lượt hỏi.
Ngược lại, khi lưu state tập trung vào Redis, bất kể request đến instance nào, nó đều đọc và ghi chung vào một nguồn dữ liệu, giúp `history_length` tăng đều đặn (0, 2, 4, 6,...).

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Lỗi gặp phải:** Khi triển khai ứng dụng, endpoint `/ready` trả về lỗi HTTP 500 (`Internal Server Error`), trong khi `/health` vẫn phản hồi 200 OK.
- **Nguyên nhân:** Qua việc kiểm tra độc lập giữa `/health` (không phụ thuộc dependency) và `/ready` (phụ thuộc Redis), xác định được service agent chưa kết nối thành công tới Redis do biến môi trường `REDIS_URL` chưa được liên kết đúng với Redis service được cấp trên platform.
- **Cách khắc phục:** Cấu hình đúng connection string của Redis service trên dashboard, hoặc sử dụng Blueprint `render.yaml` với khai báo `fromService: day12-redis` để nền tảng tự động inject biến `REDIS_URL` cho container agent. Sau khi cấu hình đúng, `/ready` phản hồi `200 {"status":"ready","redis":true}`.
