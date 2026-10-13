FROM python:3.12-slim

# pymodbus as pinned in the uv.lock of industrial-aiops v0.28.0.
RUN pip install --no-cache-dir "pymodbus==3.14.0"

WORKDIR /app
COPY simulate_line.py line.py LICENSE.iaiops ./

USER 10001:10001
EXPOSE 5020
ENTRYPOINT ["python", "-u", "/app/line.py"]
CMD ["--port", "5020", "--bind", "0.0.0.0"]
