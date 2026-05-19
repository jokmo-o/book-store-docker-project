FROM python:3.11-slim

ARG ARTIFACT_NAME
RUN test -n "$ARTIFACT_NAME" || (echo "ERROR: --build-arg ARTIFACT_NAME is required" && exit 1)

WORKDIR /app

COPY ${ARTIFACT_NAME} /tmp/app.tar.gz

RUN tar -xzf /tmp/app.tar.gz -C /app && rm /tmp/app.tar.gz

RUN pip install --no-cache-dir -r requirements.txt



RUN useradd app && chown -R app:app /app

USER app

EXPOSE 8000
# check
# we use CMD because we only have one server
CMD ["gunicorn", "book_shop.wsgi:application", "--bind", "0.0.0.0:8000"]
