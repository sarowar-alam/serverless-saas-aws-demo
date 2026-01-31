sam build -t shared-template.yaml --use-container
sam deploy --config-file shared-samconfig.toml


sam build -t tenant-template.yaml --use-container
sam deploy --config-file tenant-samconfig.toml

---

## 🧑‍💻 Author

**Md. Sarowar Alam**  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
