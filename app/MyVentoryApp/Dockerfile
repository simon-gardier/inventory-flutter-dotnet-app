FROM instrumentisto/flutter:latest
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
CMD ["flutter", "test"]
