# English Learning App

Ứng dụng học tiếng Anh toàn diện với các tính năng:
- Học ngữ pháp
- Luyện phát âm IPA
- Học từ vựng
- Luyện hội thoại

## Tính năng chính

### Ngữ pháp
- Danh sách các điểm ngữ pháp
- Bài học chi tiết với ví dụ
- Bài tập thực hành
- Theo dõi tiến độ học tập

### Phát âm IPA
- Học bảng phiên âm quốc tế
- Luyện phát âm với audio
- Bài tập nhận diện âm
- Đánh giá phát âm

### Từ vựng
- Học từ vựng theo chủ đề
- Bài tập đa dạng
- Luyện nghe và phát âm
- Theo dõi tiến độ học tập

### Hội thoại
- Các tình huống giao tiếp
- Luyện nói và nghe
- Đánh giá phát âm
- Theo dõi tiến độ

## Công nghệ sử dụng

- Flutter
- Firebase Authentication
- Cloud Firestore
- Google Sign-In
- Flutter TTS
- Flutter Sound
- Whisper API

## Cài đặt

1. Clone repository:
```bash
git clone https://github.com/your-username/english_learning_app.git
```

2. Cài đặt dependencies:
```bash
flutter pub get
```

3. Cấu hình Firebase:
- Tạo project trên Firebase Console
- Thêm ứng dụng Android/iOS
- Tải và thêm file cấu hình Firebase

4. Chạy ứng dụng:
```bash
flutter run
```

## Cấu hình và Chạy Whisper FastAPI

### Yêu cầu:
- Python >= 3.8
- CUDA GPU (tùy chọn để tăng tốc độ xử lý)
- Môi trường ảo Python

### Cài đặt:

1. Tạo môi trường ảo:
```bash
python -m venv whisper_env
source whisper_env/bin/activate  # Trên Linux/MacOS
whisper_env\Scripts\activate  # Trên Windows
```

2. Cài đặt các dependencies:
```bash
pip install fastapi uvicorn torch openai-whisper
```

### Cấu hình GPU:
- Đảm bảo đã cài đặt CUDA và PyTorch hỗ trợ GPU:
```bash
pip install torch --extra-index-url https://download.pytorch.org/whl/cu118
```

### Chạy API:

1. Khởi động API:
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

2. Kiểm tra API:
- Mở trình duyệt và truy cập `http://localhost:8000`
- Sử dụng endpoint `/transcribe` để upload file âm thanh và nhận kết quả chuyển đổi văn bản.

Ví dụ sử dụng cURL để gửi file âm thanh:
```bash
curl -X POST "http://localhost:8000/transcribe" -F "audio=@path/to/your/audio/file.wav"
```

## Đóng góp

Mọi đóng góp đều được hoan nghênh. Vui lòng tạo issue hoặc pull request để đóng góp.

## Giấy phép

MIT License
