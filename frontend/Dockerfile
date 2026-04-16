# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:3.29.3 AS build

WORKDIR /app
COPY . .
RUN flutter pub get
# Pass the backend URL at build time
ARG API_BASE_URL=http://localhost:8000
ARG WS_BASE_URL=ws://localhost:8000
RUN flutter build web \
    --dart-define=API_BASE_URL=$API_BASE_URL \
    --dart-define=WS_BASE_URL=$WS_BASE_URL

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
